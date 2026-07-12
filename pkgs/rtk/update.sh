#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git coreutils gnused gnugrep gawk perl nix

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
DEFAULT_NIX="$REPO_ROOT/pkgs/rtk/default.nix"
INSTALLABLE="path:$REPO_ROOT#rtk"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

if [[ ! -f "$DEFAULT_NIX" ]]; then
  echo "Error: $DEFAULT_NIX not found." >&2
  exit 1
fi

current_version="$(sed -n 's/^\s*version = "\([^"]*\)";/\1/p' "$DEFAULT_NIX" | head -n1)"
current_src_hash="$(sed -n 's/^\s*hash = "\([^"]*\)";/\1/p' "$DEFAULT_NIX" | head -n1)"
current_cargo_hash="$(sed -n 's/^\s*cargoHash = "\([^"]*\)";/\1/p' "$DEFAULT_NIX" | head -n1)"
echo "Current version: ${current_version:-<unknown>}"

if [[ -n "${RTK_VERSION_OVERRIDE:-}" ]]; then
  target_version="${RTK_VERSION_OVERRIDE#v}"
  echo "Using override version: v${target_version}"
else
  echo "Fetching latest release from rtk-ai/rtk..."
  target_version="$(
    git ls-remote --tags --refs https://github.com/rtk-ai/rtk.git \
      | awk '$2 ~ /^refs\/tags\/v[0-9]+\.[0-9]+\.[0-9]+$/ { print $2 }' \
      | sed 's#^refs/tags/v##' \
      | sort -Vr \
      | head -n1
  )"

  if [[ -z "$target_version" ]]; then
    echo "Error: unable to determine latest release." >&2
    exit 1
  fi

  echo "Latest release: v${target_version}"
fi

is_truthy() {
  case "${1:-}" in
    1|true|yes|y)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

hash_needs_refresh() {
  [[ -z "$1" || "$1" == "$FAKE_HASH" ]]
}

if [[ "$target_version" == "$current_version" ]] && ! is_truthy "${RTK_REFRESH_HASHES:-0}"; then
  if hash_needs_refresh "$current_src_hash" || hash_needs_refresh "$current_cargo_hash"; then
    echo "Already on target version, but hashes need refresh."
  else
    echo "Already on latest version; nothing to update."
    echo "Set RTK_REFRESH_HASHES=1 to recompute hashes."
    exit 0
  fi
fi

update_default_nix() {
  local version="$1"
  local src_hash="$2"
  local cargo_hash="$3"

  RTK_VERSION="$version" \
  RTK_SRC_HASH="$src_hash" \
  RTK_CARGO_HASH="$cargo_hash" \
  perl -0pi -e '
    s/(version = ")[^"]*(";)/$1$ENV{RTK_VERSION}$2/s or die "failed to update version\n";
    s/(hash = ")[^"]*(";)/$1$ENV{RTK_SRC_HASH}$2/s or die "failed to update source hash\n";
    s/(cargoHash = ")[^"]*(";)/$1$ENV{RTK_CARGO_HASH}$2/s or die "failed to update cargo hash\n";
  ' "$DEFAULT_NIX"
}

prefetch_source_hash() {
  local version="$1"
  local url="https://github.com/rtk-ai/rtk/archive/refs/tags/v${version}.tar.gz"
  local base32_hash

  base32_hash="$(nix-prefetch-url --unpack --type sha256 "$url")"
  nix hash convert --hash-algo sha256 --from nix32 --to sri "$base32_hash"
}

extract_got_hash() {
  sed -n 's/.*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' | tail -n1
}

prefetch_cargo_hash() {
  local version="$1"
  local src_hash="$2"
  local log_file
  log_file="$(mktemp)"
  local expr

  expr="$(cat <<EOF
let
  flake = builtins.getFlake "path:${REPO_ROOT}";
  pkgs = import flake.inputs.nixpkgs {
    system = builtins.currentSystem;
  };
in
(pkgs.rustPlatform.fetchCargoVendor {
  pname = "rtk";
  version = "${version}";
  src = pkgs.fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    tag = "v${version}";
    hash = "${src_hash}";
  };
  hash = "";
}).vendorStaging
EOF
)"

  set +e
  nix build --impure --no-link --no-write-lock-file --expr "$expr" 2>&1 | tee "$log_file" >&2
  local status="${PIPESTATUS[0]}"
  set -e

  if [[ "$status" -eq 0 ]]; then
    echo "Error: cargo vendor derivation succeeded while collecting hash." >&2
    rm -f "$log_file"
    exit 1
  fi

  local hash
  hash="$(extract_got_hash < "$log_file")"
  rm -f "$log_file"

  if [[ -z "$hash" ]]; then
    echo "Error: unable to extract cargo vendor hash from nix output." >&2
    exit 1
  fi

  printf '%s\n' "$hash"
}

echo "Collecting source hash..."
src_hash="$(prefetch_source_hash "$target_version")"
echo "  source: $src_hash"

echo "Collecting cargo vendor hash..."
cargo_hash="$(prefetch_cargo_hash "$target_version" "$src_hash")"
echo "  cargo: $cargo_hash"

echo "Updating ${DEFAULT_NIX}..."
update_default_nix "$target_version" "$src_hash" "$cargo_hash"

if is_truthy "${RTK_UPDATE_VERIFY:-0}"; then
  echo "Verifying updated package..."
  nix build --no-link --no-write-lock-file "$INSTALLABLE"
else
  echo "Skipping package build verification. Set RTK_UPDATE_VERIFY=1 to enable it."
fi

echo "Update complete: $target_version"
