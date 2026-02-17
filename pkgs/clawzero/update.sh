#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq git coreutils gnused nix python3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"
DEFAULT_NIX="$REPO_ROOT/pkgs/clawzero/default.nix"
REPO_API="https://api.github.com/repos/betta-lab/clawzero"

if [[ ! -f "$DEFAULT_NIX" ]]; then
  echo "Error: $DEFAULT_NIX not found." >&2
  exit 1
fi

current_version="$(sed -n 's/^\s*version = "\([^"]*\)";/\1/p' "$DEFAULT_NIX" | head -n1)"
if [[ -z "$current_version" ]]; then
  echo "Error: failed to read current version from $DEFAULT_NIX." >&2
  exit 1
fi

echo "Current version: $current_version"

release_json="$(curl -fsSL "${REPO_API}/releases/latest")"
latest_tag="$(printf '%s' "$release_json" | jq -r '.tag_name')"

if [[ -z "$latest_tag" || "$latest_tag" == "null" ]]; then
  echo "Error: failed to determine latest tag from releases API." >&2
  exit 1
fi

latest_version="${latest_tag#v}"
echo "Latest version: $latest_version"

declare -A targets=(
  ["x86_64-linux"]="x86_64-unknown-linux-gnu"
  ["aarch64-linux"]="aarch64-unknown-linux-gnu"
  ["x86_64-darwin"]="x86_64-apple-darwin"
  ["aarch64-darwin"]="aarch64-apple-darwin"
)

declare -A hashes
systems=(
  "x86_64-linux"
  "aarch64-linux"
  "x86_64-darwin"
  "aarch64-darwin"
)

echo "Collecting hashes from release assets..."
for system in "${systems[@]}"; do
  target="${targets[$system]}"
  asset="clawzero-v${latest_version}-${target}.tar.gz"
  digest="$(printf '%s' "$release_json" | jq -r --arg asset "$asset" '.assets[] | select(.name == $asset) | .digest')"

  if [[ -z "$digest" || "$digest" == "null" ]]; then
    echo "Error: digest not found for asset $asset" >&2
    exit 1
  fi

  hashes[$system]="$(nix hash convert --to sri "$digest")"
  echo "  $system: ${hashes[$system]}"
done

hash_json="{"
sep=""
for system in "${systems[@]}"; do
  hash_json+="${sep}\"${system}\":\"${hashes[$system]}\""
  sep=","
done
hash_json+="}"

DEFAULT_NIX="$DEFAULT_NIX" \
LATEST_VERSION="$latest_version" \
HASHES_JSON="$hash_json" \
python3 <<'PY'
import json
import os
import pathlib
import re

default_nix = pathlib.Path(os.environ["DEFAULT_NIX"])
latest = os.environ["LATEST_VERSION"]
hashes = json.loads(os.environ["HASHES_JSON"])

text = default_nix.read_text()

text, count = re.subn(r'version = "[^"]*";', f'version = "{latest}";', text, count=1)
if count == 0:
    raise SystemExit("Failed to update version field in default.nix")

for system, new_hash in hashes.items():
    pattern = r'(%s\s*=\s*\{.*?hash\s*=\s*")[^"]*(")' % re.escape(system)
    text, count = re.subn(
        pattern,
        lambda m: f"{m.group(1)}{new_hash}{m.group(2)}",
        text,
        count=1,
        flags=re.S,
    )
    if count == 0:
        raise SystemExit(f"Failed to update hash for {system}")

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
nix build --impure --expr "$build_expr"

echo "Update complete."
