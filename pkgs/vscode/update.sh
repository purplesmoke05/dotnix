#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq coreutils gnused nix

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
SOURCES_JSON="${SCRIPT_DIR}/sources.json"

platforms=(
  "x86_64-linux linux-x64"
  "aarch64-linux linux-arm64"
  "x86_64-darwin darwin"
  "aarch64-darwin darwin-arm64"
)

if [[ ! -f "$DEFAULT_NIX" || ! -f "$SOURCES_JSON" ]]; then
  echo "Error: required files not found in ${SCRIPT_DIR}" >&2
  exit 1
fi

current_version=$(
  sed -n 's/^[[:space:]]*version = "\([^"]*\)";/\1/p' "$DEFAULT_NIX" \
    | head -n1
)
echo "Current version: ${current_version:-<unknown>}"

if [[ -n "${VSCODE_VERSION_OVERRIDE:-}" ]]; then
  latest_version="${VSCODE_VERSION_OVERRIDE#v}"
  echo "Using override version: ${latest_version}"
else
  echo "Fetching latest release from microsoft/vscode..."
  latest_version=$(
    curl -fsSL "https://api.github.com/repos/microsoft/vscode/releases" \
      | jq -r '.[] | select(.prerelease == false) | .tag_name' \
      | sed 's/^v//' \
      | sort -V \
      | tail -n1
  )

  if [[ -z "$latest_version" ]]; then
    echo "Error: unable to determine latest version." >&2
    exit 1
  fi

  echo "Latest version: ${latest_version}"
fi

if [[ "$latest_version" == "$current_version" ]]; then
  echo "Already on latest version; refreshing hashes."
fi

declare -A urls
declare -A hashes

for entry in "${platforms[@]}"; do
  read -r system platform <<<"$entry"
  url="https://update.code.visualstudio.com/${latest_version}/${platform}/stable"
  echo "Prefetching ${system}: ${url}"
  base32_hash=$(nix-prefetch-url --type sha256 "$url")
  sri_hash=$(nix hash convert --hash-algo sha256 --to sri "$base32_hash")

  urls["$system"]="$url"
  hashes["$system"]="$sri_hash"

  echo "  -> ${sri_hash}"
done

sed -i "0,/version = \"[^\"]*\";/s//version = \"${latest_version}\";/" "$DEFAULT_NIX"

jq -n \
  --arg x86_64_linux_url "${urls["x86_64-linux"]}" \
  --arg x86_64_linux_hash "${hashes["x86_64-linux"]}" \
  --arg aarch64_linux_url "${urls["aarch64-linux"]}" \
  --arg aarch64_linux_hash "${hashes["aarch64-linux"]}" \
  --arg x86_64_darwin_url "${urls["x86_64-darwin"]}" \
  --arg x86_64_darwin_hash "${hashes["x86_64-darwin"]}" \
  --arg aarch64_darwin_url "${urls["aarch64-darwin"]}" \
  --arg aarch64_darwin_hash "${hashes["aarch64-darwin"]}" \
  '{
    "x86_64-linux": { url: $x86_64_linux_url, hash: $x86_64_linux_hash },
    "aarch64-linux": { url: $aarch64_linux_url, hash: $aarch64_linux_hash },
    "x86_64-darwin": { url: $x86_64_darwin_url, hash: $x86_64_darwin_hash },
    "aarch64-darwin": { url: $aarch64_darwin_url, hash: $aarch64_darwin_hash }
  }' > "$SOURCES_JSON"

echo "Update complete."
