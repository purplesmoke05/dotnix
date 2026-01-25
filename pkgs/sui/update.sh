#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq git coreutils gnused nix python3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"
DEFAULT_NIX="$REPO_ROOT/pkgs/sui/default.nix"

if [[ ! -f "$DEFAULT_NIX" ]]; then
  echo "Error: $DEFAULT_NIX not found." >&2
  exit 1
fi

current_version=$(grep -m1 'version = "' "$DEFAULT_NIX" | sed 's/.*"\([^"]*\)".*/\1/')
echo "Current version: ${current_version:-<unknown>}"

echo "Fetching latest Sui mainnet release..."
latest_version=$(curl -s https://api.github.com/repos/MystenLabs/sui/releases \
  | jq -r '.[].tag_name | select(startswith("mainnet-v")) | sub("^mainnet-v"; "")' \
  | sort -V \
  | tail -n1)

if [[ -z "$latest_version" ]]; then
  echo "Error: unable to determine latest testnet version." >&2
  exit 1
fi

echo "Latest version: $latest_version"

declare -A hashes
systems=(
  "x86_64-linux:x86_64"
  "aarch64-linux:aarch64"
)

for entry in "${systems[@]}"; do
  IFS=: read -r system suffix <<<"$entry"
  url="https://github.com/MystenLabs/sui/releases/download/mainnet-v${latest_version}/sui-mainnet-v${latest_version}-ubuntu-${suffix}.tgz"
  echo "Prefetching $system..."
  base32_hash=$(nix-prefetch-url --type sha256 "$url")
  sri_hash=$(nix hash to-sri --type sha256 "$base32_hash")
  hashes[$system]="$sri_hash"
  echo "  -> $sri_hash"
done

hash_json="{"
sep=""
for entry in "${systems[@]}"; do
  IFS=: read -r system _ <<<"$entry"
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
        lambda match: f"{match.group(1)}{new_hash}{match.group(2)}",
        text,
        count=1,
        flags=re.S,
    )
    if count == 0:
        raise SystemExit(f"Failed to update hash for {system}")

default_nix.write_text(text)
PY

echo "Update complete."
