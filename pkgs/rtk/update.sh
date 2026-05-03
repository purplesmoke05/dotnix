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

extract_got_hash() {
  sed -n 's/.*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' | tail -n1
}

build_and_expect_hash() {
  local phase="$1"
  local log_file
  log_file="$(mktemp)"

  set +e
  nix build --no-link --no-write-lock-file "$INSTALLABLE" 2>&1 | tee "$log_file" >&2
  local status="${PIPESTATUS[0]}"
  set -e

  if [[ "$status" -eq 0 ]]; then
    echo "Error: build succeeded while collecting ${phase} hash." >&2
    rm -f "$log_file"
    exit 1
  fi

  local hash
  hash="$(extract_got_hash < "$log_file")"
  rm -f "$log_file"

  if [[ -z "$hash" ]]; then
    echo "Error: unable to extract ${phase} hash from nix output." >&2
    exit 1
  fi

  printf '%s\n' "$hash"
}

echo "Collecting source hash..."
update_default_nix "$target_version" "$FAKE_HASH" "$FAKE_HASH"

src_hash="$(build_and_expect_hash "source")"
echo "  source: $src_hash"

echo "Collecting cargo hash..."
update_default_nix "$target_version" "$src_hash" "$FAKE_HASH"

cargo_hash="$(build_and_expect_hash "cargo")"
echo "  cargo: $cargo_hash"

echo "Updating ${DEFAULT_NIX}..."
update_default_nix "$target_version" "$src_hash" "$cargo_hash"

echo "Verifying updated package..."
nix build --no-link --no-write-lock-file "$INSTALLABLE"

echo "Update complete: $target_version"
