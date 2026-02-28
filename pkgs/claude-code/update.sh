#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq git coreutils gnused nix python3

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
DEFAULT_NIX="$REPO_ROOT/pkgs/claude-code/default.nix"
BASE_URL="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

if [[ ! -f "$DEFAULT_NIX" ]]; then
  echo "Error: $DEFAULT_NIX not found." >&2
  exit 1
fi

current_version="$(sed -n 's/^\s*version = "\([^"]*\)";/\1/p' "$DEFAULT_NIX" | head -n1)"
echo "Current version: ${current_version:-<unknown>}"

if [[ -n "${CLAUDE_CODE_VERSION_OVERRIDE:-}" ]]; then
  target_version="$CLAUDE_CODE_VERSION_OVERRIDE"
  echo "Using override version: $target_version"
else
  target_version="$(curl -fsSL "$BASE_URL/latest")"
  if [[ -z "$target_version" ]]; then
    echo "Error: failed to resolve latest version." >&2
    exit 1
  fi
  echo "Latest version: $target_version"
fi

manifest_json="$(curl -fsSL "$BASE_URL/$target_version/manifest.json")"
manifest_version="$(printf '%s' "$manifest_json" | jq -r '.version // empty')"
if [[ -z "$manifest_version" ]]; then
  echo "Error: failed to read manifest version." >&2
  exit 1
fi

if [[ "$manifest_version" != "$target_version" ]]; then
  echo "Warning: manifest version ($manifest_version) differs from target ($target_version)." >&2
fi

platforms=(
  "darwin-arm64"
  "darwin-x64"
  "linux-arm64"
  "linux-arm64-musl"
  "linux-x64"
  "linux-x64-musl"
)

declare -A hashes

echo "Collecting platform hashes from manifest..."
for platform in "${platforms[@]}"; do
  checksum="$(printf '%s' "$manifest_json" | jq -r --arg p "$platform" '.platforms[$p].checksum // empty')"
  if [[ -z "$checksum" ]]; then
    echo "Error: checksum not found for platform $platform" >&2
    exit 1
  fi

  sri_hash="$(nix hash convert --to sri --hash-algo sha256 "$checksum")"
  hashes[$platform]="$sri_hash"
  echo "  $platform: $sri_hash"
done

hash_json="{"
sep=""
for platform in "${platforms[@]}"; do
  hash_json+="${sep}\"${platform}\":\"${hashes[$platform]}\""
  sep=","
done
hash_json+="}"

echo "Updating ${DEFAULT_NIX}..."
DEFAULT_NIX="$DEFAULT_NIX" \
TARGET_VERSION="$manifest_version" \
HASHES_JSON="$hash_json" \
python3 <<'PY'
import json
import os
import pathlib
import re

default_nix = pathlib.Path(os.environ["DEFAULT_NIX"])
version = os.environ["TARGET_VERSION"]
hashes = json.loads(os.environ["HASHES_JSON"])

text = default_nix.read_text()

text, count = re.subn(r'(^\s*version = ")[^"]*(";)', rf'\g<1>{version}\2', text, count=1, flags=re.M)
if count == 0:
    raise SystemExit("failed to update version")

for platform, new_hash in hashes.items():
    pattern = rf'(^\s*{re.escape(platform)}\s*=\s*")[^"]*(";)'
    text, count = re.subn(pattern, rf'\g<1>{new_hash}\2', text, count=1, flags=re.M)
    if count == 0:
        raise SystemExit(f"failed to update hash for {platform}")

default_nix.write_text(text)
PY

build_expr=$(cat <<EOF
let
  flake = builtins.getFlake "${REPO_ROOT}";
  pkgs = import flake.inputs.nixpkgs {
    system = builtins.currentSystem;
    config.allowUnfree = true;
  };
in
pkgs.callPackage "${DEFAULT_NIX}" {}
EOF
)

echo "Verifying updated package..."
NIXPKGS_ALLOW_UNFREE=1 nix build --no-link --impure --expr "$build_expr"

echo "Update complete: $manifest_version"
