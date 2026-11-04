#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl git coreutils gnused nix python3

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
DEFAULT_NIX="$REPO_ROOT/pkgs/brave/default.nix"

if [[ ! -f "$DEFAULT_NIX" ]]; then
  echo "Error: $DEFAULT_NIX not found." >&2
  exit 1
fi

current_version=$(grep -m1 'version = "' "$DEFAULT_NIX" | sed 's/.*"\([^"]*\)".*/\1/')
echo "Current version: ${current_version:-<unknown>}"

if [[ -n "${BRAVE_VERSION_OVERRIDE:-}" ]]; then
  latest_version="${BRAVE_VERSION_OVERRIDE#v}"
  echo "Using override version: v${latest_version}"
else
  # Brave's own channel endpoint. GitHub also lists Beta and Nightly as regular releases. / Brave 公式のチャンネル情報を使う。GitHub には Beta や Nightly も通常のリリースとして並ぶ。
  echo "Fetching the stable version from versions.brave.com..."
  latest_version=""
  for channel in release-linux-x64 release-linux-arm64 release-macos-arm64; do
    version=$(curl -fsSL "https://versions.brave.com/latest/${channel}.version")
    echo "  ${channel}: ${version}"
    if [[ -n "$latest_version" && "$version" != "$latest_version" ]]; then
      echo "Error: stable versions differ between platforms; try again later." >&2
      exit 1
    fi
    latest_version="$version"
  done
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

if [[ "$latest_version" == "$current_version" ]] && ! is_truthy "${BRAVE_REFRESH_HASHES:-0}"; then
  echo "Already on latest version; nothing to update."
  echo "Set BRAVE_REFRESH_HASHES=1 to recompute hashes."
  exit 0
fi

# Nix system → Brave release asset name. / Nix 系統名 → Brave 配布 asset 名。
artifacts=(
  "x86_64-linux brave-browser_${latest_version}_amd64.deb"
  "aarch64-linux brave-browser_${latest_version}_arm64.deb"
  "aarch64-darwin Brave-Browser-arm64.dmg"
)

declare -A urls
for entry in "${artifacts[@]}"; do
  read -r system asset <<<"$entry"
  urls[$system]="https://github.com/brave/brave-browser/releases/download/v${latest_version}/${asset}"
done

# Hash from the release digests so artifacts for other systems are not downloaded. / 他システム向け artifact をダウンロードしないよう、リリースの digest からハッシュを得る。
echo "Resolving release hashes..."
hash_lines="$("$REPO_ROOT/scripts/github-release-hashes" "${urls[@]}")"
declare -A url_hashes
while IFS=$'\t' read -r url sri_hash; do
  url_hashes[$url]="$sri_hash"
done <<<"$hash_lines"

hash_json="{"
sep=""
for entry in "${artifacts[@]}"; do
  read -r system _ <<<"$entry"
  hash="${url_hashes[${urls[$system]}]}"
  echo "  $system -> $hash"
  hash_json+="${sep}\"${system}\":\"${hash}\""
  sep=","
done
hash_json+="}"

echo "Updating ${DEFAULT_NIX}..."

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
    pattern = r'(%s = \{\s*url = "[^"]*";\s*hash = ")([^"]*)(";)' % re.escape(system)
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

if is_truthy "${BRAVE_UPDATE_VERIFY:-0}"; then
  echo "Verifying updated package..."
  nix build --no-link --no-write-lock-file "path:$REPO_ROOT#brave"
else
  echo "Skipping package build verification. Set BRAVE_UPDATE_VERIFY=1 to enable it."
fi

echo "Update complete: v${latest_version}"
