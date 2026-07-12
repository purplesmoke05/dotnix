#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl git coreutils gnused nix python3

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
DEFAULT_NIX="$REPO_ROOT/pkgs/herdr/default.nix"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
MANIFEST_URL="https://herdr.dev/latest.json"

# Nix system → manifest asset key. / Nix 系統名 → マニフェスト asset キー。
# linux-x86_64, linux-aarch64, macos-x86_64, macos-aarch64
artifacts=(
  "x86_64-linux linux-x86_64"
  "aarch64-linux linux-aarch64"
  "x86_64-darwin macos-x86_64"
  "aarch64-darwin macos-aarch64"
)

if [[ ! -f "$DEFAULT_NIX" ]]; then
  echo "Error: $DEFAULT_NIX not found." >&2
  exit 1
fi

current_version=$(grep -m1 'version = "' "$DEFAULT_NIX" | sed 's/.*"\([^"]*\)".*/\1/')
echo "Current version: ${current_version:-<unknown>}"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

manifest_file="$tmpdir/latest.json"
echo "Fetching Herdr release manifest..."
curl -fsSL --retry 3 --connect-timeout 10 --max-time 20 "$MANIFEST_URL" -o "$manifest_file"

manifest_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$manifest_file")"
if [[ -z "$manifest_version" ]]; then
  echo "Error: failed to read version from manifest." >&2
  exit 1
fi

if [[ -n "${HERDR_VERSION_OVERRIDE:-}" ]]; then
  latest_tag="${HERDR_VERSION_OVERRIDE#v}"
  echo "Using override version: v${latest_tag}"
else
  latest_tag="$manifest_version"
  echo "Latest release: v${latest_tag}"
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

hashes_need_refresh() {
  DEFAULT_NIX="$DEFAULT_NIX" \
  FAKE_HASH="$FAKE_HASH" \
  python3 <<'PY'
import os
import pathlib
import re
import sys

default_nix = pathlib.Path(os.environ["DEFAULT_NIX"])
fake_hash = os.environ["FAKE_HASH"]
text = default_nix.read_text()
systems = ("x86_64-linux", "aarch64-linux", "x86_64-darwin", "aarch64-darwin")

for system in systems:
    pattern = re.escape(system) + r'\s*=\s*\{[^}]*?hash\s*=\s*"([^"]*)"[^}]*?}'
    match = re.search(pattern, text, flags=re.S)
    if match is None or match.group(1) in ("", fake_hash):
        sys.exit(0)

sys.exit(1)
PY
}

if [[ "$latest_tag" == "$current_version" ]] && ! is_truthy "${HERDR_REFRESH_HASHES:-0}"; then
  if hashes_need_refresh; then
    echo "Already on target version, but hashes need refresh."
  else
    echo "Already on latest version; nothing to update."
    echo "Set HERDR_REFRESH_HASHES=1 to recompute hashes."
    exit 0
  fi
fi

declare -A hashes

for entry in "${artifacts[@]}"; do
  read -r system asset_key <<<"$entry"
  url="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["assets"][sys.argv[2]])' "$manifest_file" "$asset_key")"
  if [[ -z "$url" ]]; then
    echo "Error: asset URL not found in manifest for $asset_key." >&2
    exit 1
  fi
  echo "Prefetching ${system} asset: ${url##*/}"
  base32_hash=$(nix-prefetch-url --type sha256 "$url")
  sri_hash=$(nix hash convert --hash-algo sha256 --from nix32 --to sri "$base32_hash")
  hashes[$system]="$sri_hash"
  echo "  -> $sri_hash"
done

echo "Updating ${DEFAULT_NIX}..."

hash_json="{"
sep=""
for entry in "${artifacts[@]}"; do
  read -r system _ <<<"$entry"
  hash="${hashes[$system]}"
  hash_json+="${sep}\"${system}\":\"${hash}\""
  sep=","
done
hash_json+="}"

DEFAULT_NIX="$DEFAULT_NIX" \
LATEST_TAG="$latest_tag" \
HASHES_JSON="$hash_json" \
python3 <<'PY'
import json
import os
import pathlib
import re

default_nix = pathlib.Path(os.environ["DEFAULT_NIX"])
latest = os.environ["LATEST_TAG"]
hashes = json.loads(os.environ["HASHES_JSON"])

text = default_nix.read_text()

text, count = re.subn(r'version = "[^"]*";', f'version = "{latest}";', text, count=1)
if count == 0:
    raise SystemExit("Failed to update version field in default.nix")

for system, new_hash in hashes.items():
    pattern = r'(%s = \{\s*asset = "[^"]*";\s*hash = ")([^"]*)(";)' % re.escape(system)
    text, count = re.subn(
        pattern,
        lambda match: f"{match.group(1)}{new_hash}{match.group(3)}",
        text,
        count=1,
        flags=re.S,
    )
    if count == 0:
        raise SystemExit(f"Failed to update hash for {system}")

default_nix.write_text(text)
PY

if is_truthy "${HERDR_UPDATE_VERIFY:-0}"; then
  echo "Verifying updated package..."
  nix build --no-link --no-write-lock-file "path:$REPO_ROOT#herdr"
else
  echo "Skipping package build verification. Set HERDR_UPDATE_VERIFY=1 to enable it."
fi

echo "Update complete: v${latest_tag}"