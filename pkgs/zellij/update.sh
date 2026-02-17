#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git curl jq coreutils gnused nix nix-prefetch-github python3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"
DEFAULT_NIX="$REPO_ROOT/pkgs/zellij/default.nix"
UPSTREAM_URL="https://github.com/zellij-org/zellij.git"
UPSTREAM_BRANCH="main"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

if [[ ! -f "$DEFAULT_NIX" ]]; then
  echo "Error: $DEFAULT_NIX not found." >&2
  exit 1
fi

current_rev="$(sed -n 's/^\s*rev = "\([0-9a-f]\{40\}\)";/\1/p' "$DEFAULT_NIX" | head -n1)"
if [[ -z "$current_rev" ]]; then
  echo "Error: failed to read current rev from $DEFAULT_NIX." >&2
  exit 1
fi

echo "Current rev: $current_rev"
echo "Fetching latest commit on ${UPSTREAM_BRANCH}..."
latest_rev="$(git ls-remote "$UPSTREAM_URL" "refs/heads/${UPSTREAM_BRANCH}" | awk '{print $1}')"
if [[ -z "$latest_rev" ]]; then
  echo "Error: failed to fetch latest rev from upstream." >&2
  exit 1
fi

if [[ "$latest_rev" == "$current_rev" ]]; then
  echo "Already up-to-date on ${UPSTREAM_BRANCH}: $latest_rev"
  exit 0
fi

echo "New rev: $latest_rev"
echo "Prefetching source hash..."
source_hash="$(nix-prefetch-github zellij-org zellij --rev "$latest_rev" 2>/dev/null | jq -r '.hash')"
if [[ -z "$source_hash" || "$source_hash" == "null" ]]; then
  echo "Error: failed to prefetch source hash." >&2
  exit 1
fi

echo "Detecting upstream workspace version..."
workspace_version="$(
  curl -fsSL "https://raw.githubusercontent.com/zellij-org/zellij/${latest_rev}/Cargo.toml" \
    | sed -n '/^\[workspace\.package\]/,/^\[/{s/^version = "\([^"]*\)".*/\1/p}' \
    | head -n1
)"
if [[ -z "$workspace_version" ]]; then
  echo "Error: failed to detect workspace version from Cargo.toml." >&2
  exit 1
fi

new_version="${workspace_version}-unstable-$(date -u +%F)"
echo "New version: $new_version"
echo "Source hash: $source_hash"

DEFAULT_NIX="$DEFAULT_NIX" \
LATEST_REV="$latest_rev" \
SOURCE_HASH="$source_hash" \
NEW_VERSION="$new_version" \
FAKE_HASH="$FAKE_HASH" \
python3 <<'PY'
import os
import pathlib
import re

default_nix = pathlib.Path(os.environ["DEFAULT_NIX"])
latest_rev = os.environ["LATEST_REV"]
source_hash = os.environ["SOURCE_HASH"]
new_version = os.environ["NEW_VERSION"]
fake_hash = os.environ["FAKE_HASH"]

text = default_nix.read_text()

text, count = re.subn(r'version = "[^"]*";', f'version = "{new_version}";', text, count=1)
if count == 0:
    raise SystemExit("Failed to update version")

text, count = re.subn(r'rev = "[0-9a-f]{40}";', f'rev = "{latest_rev}";', text, count=1)
if count == 0:
    raise SystemExit("Failed to update rev")

text, count = re.subn(r'hash = "[^"]*";', f'hash = "{source_hash}";', text, count=1)
if count == 0:
    raise SystemExit("Failed to update source hash")

text, count = re.subn(r'cargoHash = "[^"]*";', f'cargoHash = "{fake_hash}";', text, count=1)
if count == 0:
    raise SystemExit("Failed to set temporary cargoHash")

default_nix.write_text(text)
PY

build_expr=$(cat <<EOF
let
  flake = builtins.getFlake "${REPO_ROOT}";
  pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; };
in
pkgs.callPackage "${DEFAULT_NIX}" {}
EOF
)

tmpfile="$(mktemp)"
echo "Resolving cargoHash from build output..."
if nix build --impure --expr "$build_expr" 2>&1 | tee "$tmpfile"; then
  echo "Error: build unexpectedly succeeded while cargoHash is fake." >&2
  rm -f "$tmpfile"
  exit 1
fi

correct_hash="$(grep -o 'got:[[:space:]]*sha256-[^[:space:]]*' "$tmpfile" | sed 's/got:[[:space:]]*//' | tail -n1)"
rm -f "$tmpfile"

if [[ -z "$correct_hash" ]]; then
  echo "Error: failed to extract cargoHash from build output." >&2
  exit 1
fi

echo "Resolved cargoHash: $correct_hash"

DEFAULT_NIX="$DEFAULT_NIX" CORRECT_HASH="$correct_hash" python3 <<'PY'
import os
import pathlib
import re

default_nix = pathlib.Path(os.environ["DEFAULT_NIX"])
correct_hash = os.environ["CORRECT_HASH"]

text = default_nix.read_text()
text, count = re.subn(r'cargoHash = "[^"]*";', f'cargoHash = "{correct_hash}";', text, count=1)
if count == 0:
    raise SystemExit("Failed to update cargoHash")
default_nix.write_text(text)
PY

echo "Verifying updated package..."
nix build --impure --expr "$build_expr"

echo "Update complete."
