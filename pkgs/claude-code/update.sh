#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl coreutils gnused nix nodejs git python3

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
PKG_DIR="$REPO_ROOT/pkgs/claude-code"
DEFAULT_NIX="$PKG_DIR/default.nix"
LOCK_FILE="$PKG_DIR/package-lock.json"

if [[ ! -f "$DEFAULT_NIX" ]]; then
  echo "Error: $DEFAULT_NIX not found" >&2
  exit 1
fi

current_version=$(sed -n 's/^[[:space:]]*version = "\([^"]*\)";.*/\1/p' "$DEFAULT_NIX" | head -n1)
echo "Current version: ${current_version:-<unknown>}"

if [[ -n "${CLAUDE_CODE_VERSION_OVERRIDE:-}" ]]; then
  target_version="$CLAUDE_CODE_VERSION_OVERRIDE"
  echo "Using override version: $target_version"
else
  target_version=$(npm view @anthropic-ai/claude-code version)
  if [[ -z "$target_version" ]]; then
    echo "Error: failed to resolve latest version from npm" >&2
    exit 1
  fi
  echo "Latest version: $target_version"
fi

artifact_url="https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${target_version}.tgz"

echo "Prefetching source hash..."
base32_hash=$(nix-prefetch-url --type sha256 --unpack "$artifact_url")
source_hash=$(nix hash convert --hash-algo sha256 "$base32_hash")
echo "Source hash: $source_hash"

tmpdir=$(mktemp -d)
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

echo "Generating package-lock.json..."
curl -L -sSf "$artifact_url" -o "$tmpdir/src.tgz"
tar -xzf "$tmpdir/src.tgz" -C "$tmpdir"
(
  cd "$tmpdir/package"
  npm install --package-lock-only --ignore-scripts --no-audit --no-fund >/dev/null
)
install -m 0644 "$tmpdir/package/package-lock.json" "$LOCK_FILE"

echo "Updating version and source hash in default.nix..."
DEFAULT_NIX="$DEFAULT_NIX" TARGET_VERSION="$target_version" SOURCE_HASH="$source_hash" python3 <<'PY'
import os
import pathlib
import re

path = pathlib.Path(os.environ["DEFAULT_NIX"])
version = os.environ["TARGET_VERSION"]
source_hash = os.environ["SOURCE_HASH"]
text = path.read_text()

text, count = re.subn(r'(^\s*version = ")[^"]*(";)', rf'\g<1>{version}\2', text, count=1, flags=re.M)
if count == 0:
    raise SystemExit("failed to update version")

text, count = re.subn(r'(^\s*hash = ")[^"]*(";)', rf'\g<1>{source_hash}\2', text, count=1, flags=re.M)
if count == 0:
    raise SystemExit("failed to update src hash")

text, count = re.subn(
    r'(^\s*npmDepsHash = ")[^"]*(";)',
    r'\g<1>sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\2',
    text,
    count=1,
    flags=re.M,
)
if count == 0:
    raise SystemExit("failed to seed npmDepsHash")

path.write_text(text)
PY

cat > "$tmpdir/build.nix" <<EOFNIX
let
  flake = builtins.getFlake (toString $REPO_ROOT);
  pkgs = import flake.inputs.nixpkgs {
    system = builtins.currentSystem;
    config.allowUnfree = true;
  };
in
  pkgs.callPackage $DEFAULT_NIX { }
EOFNIX

echo "Resolving npmDepsHash..."
set +e
build_output=$(AUTHORIZED=1 NIXPKGS_ALLOW_UNFREE=1 nix build --no-link --impure --file "$tmpdir/build.nix" 2>&1)
build_code=$?
set -e

if [[ $build_code -eq 0 ]]; then
  echo "Error: expected hash mismatch did not occur" >&2
  exit 1
fi

npm_deps_hash=$(echo "$build_output" | sed -nE 's/.*got:[[:space:]]*(sha256-[A-Za-z0-9+/=]+).*/\1/p' | tail -n1)
if [[ -z "$npm_deps_hash" ]]; then
  echo "$build_output"
  echo "Error: could not extract npmDepsHash" >&2
  exit 1
fi

echo "npmDepsHash: $npm_deps_hash"

DEFAULT_NIX="$DEFAULT_NIX" NPM_DEPS_HASH="$npm_deps_hash" python3 <<'PY'
import os
import pathlib
import re

path = pathlib.Path(os.environ["DEFAULT_NIX"])
npm_deps_hash = os.environ["NPM_DEPS_HASH"]
text = path.read_text()

text, count = re.subn(
    r'(^\s*npmDepsHash = ")[^"]*(";)',
    rf'\g<1>{npm_deps_hash}\2',
    text,
    count=1,
    flags=re.M,
)
if count == 0:
    raise SystemExit("failed to update npmDepsHash")

path.write_text(text)
PY

echo "Verifying build..."
AUTHORIZED=1 NIXPKGS_ALLOW_UNFREE=1 nix build --no-link --impure --file "$tmpdir/build.nix" >/dev/null

echo "Update complete: $target_version"
