#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq git coreutils gnused nix python3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"
DEFAULT_NIX="$REPO_ROOT/pkgs/sui/default.nix"
INSTALLABLE="path:$REPO_ROOT#sui"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

systems=(
  "x86_64-linux:x86_64"
  "aarch64-linux:aarch64"
)

if [[ ! -f "$DEFAULT_NIX" ]]; then
  echo "Error: $DEFAULT_NIX not found." >&2
  exit 1
fi

current_version=$(grep -m1 'version = "' "$DEFAULT_NIX" | sed 's/.*"\([^"]*\)".*/\1/')
echo "Current version: ${current_version:-<unknown>}"

if [[ -n "${SUI_VERSION_OVERRIDE:-}" ]]; then
  target_version="${SUI_VERSION_OVERRIDE#mainnet-v}"
  target_version="${target_version#v}"
  echo "Using override version: mainnet-v${target_version}"
else
  echo "Fetching latest Sui mainnet release..."
  target_version=$(curl -fsSL https://api.github.com/repos/MystenLabs/sui/releases \
    | jq -r '.[].tag_name | select(startswith("mainnet-v")) | sub("^mainnet-v"; "")' \
    | sort -V \
    | tail -n1)

  if [[ -z "$target_version" ]]; then
    echo "Error: unable to determine latest mainnet version." >&2
    exit 1
  fi

  echo "Latest version: $target_version"
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

current_hash_for() {
  local system="$1"

  SYSTEM="$system" \
  DEFAULT_NIX="$DEFAULT_NIX" \
  python3 <<'PY'
import os
import pathlib
import re

default_nix = pathlib.Path(os.environ["DEFAULT_NIX"])
system = os.environ["SYSTEM"]
text = default_nix.read_text()
pattern = re.escape(system) + r'\s*=\s*\{.*?hash\s*=\s*"([^"]*)"'
match = re.search(pattern, text, flags=re.S)
if match:
    print(match.group(1), end="")
PY
}

hashes_need_refresh() {
  local entry system

  for entry in "${systems[@]}"; do
    IFS=: read -r system _ <<<"$entry"
    if hash_needs_refresh "$(current_hash_for "$system")"; then
      return 0
    fi
  done

  return 1
}

if [[ "$target_version" == "$current_version" ]] && ! is_truthy "${SUI_REFRESH_HASHES:-0}"; then
  if hashes_need_refresh; then
    echo "Already on target version, but hashes need refresh."
  else
    echo "Already on latest version; nothing to update."
    echo "Set SUI_REFRESH_HASHES=1 to recompute hashes."
    exit 0
  fi
fi

declare -A hashes
for entry in "${systems[@]}"; do
  IFS=: read -r system suffix <<<"$entry"
  url="https://github.com/MystenLabs/sui/releases/download/mainnet-v${target_version}/sui-mainnet-v${target_version}-ubuntu-${suffix}.tgz"
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
TARGET_VERSION="$target_version" \
HASHES_JSON="$hash_json" \
python3 <<'PY'
import json
import os
import pathlib
import re

default_nix = pathlib.Path(os.environ["DEFAULT_NIX"])
target = os.environ["TARGET_VERSION"]
hashes = json.loads(os.environ["HASHES_JSON"])

text = default_nix.read_text()

text, count = re.subn(r'version = "[^"]*";', f'version = "{target}";', text, count=1)
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

if is_truthy "${SUI_UPDATE_VERIFY:-0}"; then
  echo "Verifying updated package..."
  nix build --no-link --no-write-lock-file "$INSTALLABLE"
else
  echo "Skipping package build verification. Set SUI_UPDATE_VERIFY=1 to enable it."
fi

echo "Update complete: $target_version"
