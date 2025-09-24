#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq git coreutils gnused nix

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
FLAKE_FILE="$REPO_ROOT/flake.nix"

# Extract current pinned version inside the codex overlay block
currentVersion=$(sed -n '/codex = prev\.codex\.overrideAttrs/,/};/ s/.*version = "\([^"]*\)";.*/\1/p' "$FLAKE_FILE" | head -n1)
echo "Current codex version in flake.nix: ${currentVersion:-<none>}"

echo "Querying latest rust tag from openai/codex..."
latest_tag=$(git ls-remote --tags --refs https://github.com/openai/codex.git \
  | awk -F/ '/refs\/tags\/rust-v[0-9]+\.[0-9]+\.[0-9]+$/ {print $NF}' \
  | sed 's/^rust-v//' \
  | sort -V \
  | tail -n1)

if [[ -z "${latest_tag}" ]]; then
  echo "Error: Could not determine latest rust tag from GitHub." >&2
  exit 1
fi

echo "Latest rust tag: rust-v${latest_tag}"

if [[ "${latest_tag}" == "${currentVersion}" ]]; then
  echo "Already at latest version (${currentVersion}). Will still verify hashes."
fi

# Prefetch GitHub tarball to compute src sha256 (SRI)
tar_url="https://github.com/openai/codex/archive/refs/tags/rust-v${latest_tag}.tar.gz"
echo "Prefetching tarball: $tar_url"
tar_store_path=$(nix-prefetch-url --unpack "$tar_url")
src_sri=$(nix-hash --to-sri --type sha256 "$tar_store_path")
echo "Computed src sha256 (SRI): $src_sri"

echo "Patching flake.nix version and src sha256..."
# 1) Update version inside the codex overlay block
sed -i \
  -e '/codex = prev\.codex\.overrideAttrs/,/};/ s|\(version = \)"[^"]*";|\1"'"${latest_tag}"'";|' \
  "$FLAKE_FILE"

# 2) Update only the fetchFromGitHub sha256 (not cargoDeps.hash)
sed -i \
  -e '/src = .*fetchFromGitHub/,/};/ s|^\([[:space:]]*sha256 = \)"[^"]*";|\1"'"${src_sri}"'";|' \
  "$FLAKE_FILE"

# 3) Compute cargo vendor hash WITHOUT compiling Codex
placeholder_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

echo "Computing cargo vendor hash without compiling Codex (fast path)..."
# Build a minimal Nix expression via heredoc to avoid escape issues
expr_vendor_placeholder=$(cat <<EOF
let
  flake = builtins.getFlake (toString ./.);
  pkgs = import flake.inputs.nixpkgs {
    system = builtins.currentSystem;
    overlays = [ (import flake.inputs.rust-overlay) flake.overlays.default ];
    config.allowUnfree = true;
  };
  src = pkgs.fetchFromGitHub {
    owner = "openai"; repo = "codex"; rev = "rust-v${latest_tag}"; sha256 = "${src_sri}";
  };
  vendor = pkgs.rustPlatform.fetchCargoVendor {
    src = "\${src}/codex-rs";
    hash = "${placeholder_hash}";
  };
in vendor
EOF
)
set +e
build_output=$(cd "$REPO_ROOT" && nix build --impure --expr "$expr_vendor_placeholder" 2>&1)
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Vendor derivation succeeded with placeholder (unexpected); continuing."
else
  echo "$build_output" | sed -n '1,200p'
fi

got_hash=$(echo "$build_output" | grep -oE 'sha256-[A-Za-z0-9+/=]+' | tail -n1)

if [[ -z "${got_hash}" ]]; then
  echo "Error: Could not extract cargo vendor hash from build output." >&2
  exit 1
fi

echo "Detected cargoDeps.hash: $got_hash"

echo "Updating cargoDeps.hash in flake.nix..."
sed -i \
  -e '/cargoDeps = .*fetchCargoVendor/,/};/ s|\(hash = \)"[^"]*";|\1"'"${got_hash}"'";|' \
  "$FLAKE_FILE"

echo "Verifying vendor hash only (no compilation)..."
expr_vendor_verify=$(cat <<EOF
let
  flake = builtins.getFlake (toString ./.);
  pkgs = import flake.inputs.nixpkgs {
    system = builtins.currentSystem;
    overlays = [ (import flake.inputs.rust-overlay) flake.overlays.default ];
    config.allowUnfree = true;
  };
  src = pkgs.fetchFromGitHub {
    owner = "openai"; repo = "codex"; rev = "rust-v${latest_tag}"; sha256 = "${src_sri}";
  };
  vendor = pkgs.rustPlatform.fetchCargoVendor {
    src = "\${src}/codex-rs";
    hash = "${got_hash}";
  };
in vendor
EOF
)
cd "$REPO_ROOT" && nix build --impure --expr "$expr_vendor_verify"

echo "Update completed successfully: rust-v${latest_tag}"
