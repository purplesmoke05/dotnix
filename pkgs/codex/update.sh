#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq git coreutils gnused nix

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
FLAKE_FILE="$REPO_ROOT/flake.nix"

# Extract current pinned version inside the codex overlay block
currentVersion=$(sed -n '/codex = prev\.codex\.overrideAttrs/,/};/ s/.*version = "\([^"]*\)";.*/\1/p' "$FLAKE_FILE" | head -n1)
echo "Current codex version in flake.nix: ${currentVersion:-<none>}"

# Find the latest rust-v* tag from GitHub (sorted semver, pick highest)
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
# Update version inside the codex overlay block
sed -i \
  -e '/codex = prev\.codex\.overrideAttrs/,/};/ s|\(version = \)"[^"]*";|\1"'"${latest_tag}"'";|' \
  "$FLAKE_FILE"

# Update only the fetchFromGitHub sha256 (not cargoDeps.hash)
sed -i \
  -e '/src = .*fetchFromGitHub/,/};/ s|^\([[:space:]]*sha256 = \)"[^"]*";|\1"'"${src_sri}"'";|' \
  "$FLAKE_FILE"

# Set placeholder for cargoDeps.hash to trigger fixed-output error and capture the right hash
placeholder_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
sed -i \
  -e '/cargoDeps = .*fetchCargoVendor/,/};/ s|\(hash = \)"[^"]*";|\1"'"${placeholder_hash}"'";|' \
  "$FLAKE_FILE"

echo "Building pkgs.codex to discover cargo vendor hash..."
set +e
build_output=$(cd "$REPO_ROOT" && nix build --impure --expr '
let
  flake = builtins.getFlake (toString ./.);
  pkgs = import flake.inputs.nixpkgs {
    system = builtins.currentSystem;
    overlays = [ (import flake.inputs.rust-overlay) flake.overlays.default ];
    config.allowUnfree = true;
  };
in pkgs.codex
' 2>&1)
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Build succeeded without needing cargoDeps hash update (unexpected if placeholder was set)."
else
  echo "$build_output" | sed -n '1,200p'
fi

# Extract the suggested hash from error: lines usually contain: "got: sha256-..."
got_hash=$(echo "$build_output" \
  | grep -E 'got:.*sha256-' \
  | grep -oE 'sha256-[A-Za-z0-9+/=]+' \
  | tail -n1)

if [[ -z "${got_hash}" ]]; then
  echo "Error: Could not extract cargo vendor hash from build output." >&2
  exit 1
fi

echo "Detected cargoDeps.hash: $got_hash"

echo "Updating cargoDeps.hash in flake.nix..."
sed -i \
  -e '/cargoDeps = .*fetchCargoVendor/,/};/ s|\(hash = \)"[^"]*";|\1"'"${got_hash}"'";|' \
  "$FLAKE_FILE"

echo "Verifying build with updated cargoDeps.hash..."
cd "$REPO_ROOT" && nix build --impure --expr '
let
  flake = builtins.getFlake (toString ./.);
  pkgs = import flake.inputs.nixpkgs {
    system = builtins.currentSystem;
    overlays = [ (import flake.inputs.rust-overlay) flake.overlays.default ];
    config.allowUnfree = true;
  };
in pkgs.codex
'

echo "Update completed successfully: rust-v${latest_tag}"
