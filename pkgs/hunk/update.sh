#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git coreutils gnused nix python3

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
DEFAULT_NIX="$REPO_ROOT/pkgs/hunk/default.nix"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# Nix system → Hunk release asset name. / Nix 系統名 → Hunk 配布 asset 名。
artifacts=(
  "x86_64-linux hunkdiff-linux-x64.tar.gz"
  "aarch64-linux hunkdiff-linux-arm64.tar.gz"
  "x86_64-darwin hunkdiff-darwin-x64.tar.gz"
  "aarch64-darwin hunkdiff-darwin-arm64.tar.gz"
)

if [[ ! -f "$DEFAULT_NIX" ]]; then
  echo "Error: $DEFAULT_NIX not found." >&2
  exit 1
fi

current_version=$(grep -m1 'version = "' "$DEFAULT_NIX" | sed 's/.*"\([^"]*\)".*/\1/')
echo "Current version: ${current_version:-<unknown>}"

if [[ -n "${HUNK_VERSION_OVERRIDE:-}" ]]; then
  latest_tag="${HUNK_VERSION_OVERRIDE#v}"
  echo "Using override version: v${latest_tag}"
else
  echo "Fetching latest release from modem-dev/hunk..."
  latest_tag=$(
    git ls-remote --tags --refs https://github.com/modem-dev/hunk.git \
    | awk '$2 ~ /refs\/tags\/v[0-9]+\.[0-9]+\.[0-9]+$/ { print $2 }' \
    | sed 's#^refs/tags/v##' \
    | sort -Vr \
    | head -n1
  )

  if [[ -z "$latest_tag" ]]; then
    echo "Error: unable to determine latest release." >&2
    exit 1
  fi

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

if [[ "$latest_tag" == "$current_version" ]] && ! is_truthy "${HUNK_REFRESH_HASHES:-0}"; then
  if hashes_need_refresh; then
    echo "Already on target version, but hashes need refresh."
  else
    echo "Already on latest version; nothing to update."
    echo "Set HUNK_REFRESH_HASHES=1 to recompute hashes."
    exit 0
  fi
fi

declare -A hashes

for entry in "${artifacts[@]}"; do
  read -r system asset <<<"$entry"
  url="https://github.com/modem-dev/hunk/releases/download/v${latest_tag}/${asset}"
  echo "Prefetching ${system} artifact: ${asset}"
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

if is_truthy "${HUNK_UPDATE_VERIFY:-0}"; then
  echo "Verifying updated package..."
  nix build --no-link --no-write-lock-file "path:$REPO_ROOT#hunk"
else
  echo "Skipping package build verification. Set HUNK_UPDATE_VERIFY=1 to enable it."
fi

echo "Update complete: v${latest_tag}"