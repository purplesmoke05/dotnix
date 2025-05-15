#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq common-updater-scripts coreutils gnused nix

set -euo pipefail

# The Nix file to update
DEFAULT_NIX_FILE="$(dirname "$0")/default.nix"
VERSION_HISTORY_URL="https://raw.githubusercontent.com/oslook/cursor-ai-downloads/refs/heads/main/version-history.json"

# Get the current version from the default.nix file
currentVersion=$(sed -n 's/\s*version = "\([^"]*\)";/\1/p' "$DEFAULT_NIX_FILE" | head -n1 | tr -d '"')
echo "Current version in $DEFAULT_NIX_FILE: $currentVersion"

# Platform mapping from Nix architecture to version-history.json platform keys
declare -A platform_map=(
  [x86_64-linux]="linux-x64"
  [aarch64-linux]="linux-arm64"
  [x86_64-darwin]="darwin-x64"
  [aarch64-darwin]="darwin-arm64"
)

echo "Fetching version history from $VERSION_HISTORY_URL..."
version_history_json=$(curl -s "$VERSION_HISTORY_URL")

if [[ -z "$version_history_json" ]]; then
  echo "Error: Could not fetch version history JSON. Aborting."
  exit 1
fi

# Get the latest version entry (assuming the first entry is the latest)
latest_version_data=$(echo "$version_history_json" | jq -r '.versions[0]')

if [[ -z "$latest_version_data" || "$latest_version_data" == "null" ]]; then
  echo "Error: Could not parse latest version data from JSON. Aborting."
  exit 1
fi

latest_version_str=$(echo "$latest_version_data" | jq -r '.version')

echo "Latest version found in history: $latest_version_str"

if [[ -z "$latest_version_str" || "$latest_version_str" == "null" ]]; then
  echo "Error: Could not extract latest version string. Aborting."
  exit 1
fi

# Check if the latest version from history is the same as current
if [[ "$latest_version_str" == "$currentVersion" ]]; then
  echo "Version $latest_version_str is the same as current ($currentVersion)."
  # Still proceed if any hash is a placeholder to ensure all hashes are correct
  needs_hash_update=0
  for nix_platform in "${!platform_map[@]}"; do
    current_hash=$(sed -E -n 's/\s*'"$nix_platform"' = fetchurl \{[^}]*hash = "([^"]*)";/\1/p' "$DEFAULT_NIX_FILE" | head -n1)
    if [[ "$current_hash" == *"AAAAA="* || "$current_hash" == *"BBBBB="* || "$current_hash" == *"CCCCC="* || "$current_hash" == *"DDDDD="* ]]; then
      echo "Placeholder hash found for $nix_platform: $current_hash. Hash update needed."
      needs_hash_update=1
      break
    fi
  done
  if [[ "$needs_hash_update" -eq 0 ]]; then
    echo "No placeholder hashes found and version is current. Exiting."
    exit 0
  fi
  echo "Version is current, but placeholder hashes need updating or verification."
fi

echo "Updating default.nix to version $latest_version_str"

# Update the main version string
sed -i 's/\s*version = "[^"]*";/  version = "'"$latest_version_str"'";/' "$DEFAULT_NIX_FILE"

for nix_platform in "${!platform_map[@]}"; do
  json_platform_key="${platform_map[$nix_platform]}"

  url=$(echo "$latest_version_data" | jq -r --arg platform_key "$json_platform_key" '.platforms[$platform_key]')

  if [[ -z "$url" || "$url" == "null" ]]; then
    echo "Warning: Could not find URL for $nix_platform (key: $json_platform_key) in version $latest_version_str. Skipping this platform."
    continue
  fi

  echo "Prefetching URL for $nix_platform: $url"
  if ! curl --output /dev/null --silent --head --fail "$url"; then
    echo "Error: URL $url is not accessible. Skipping $nix_platform."
    continue
  fi

  source_path=$(nix-prefetch-url "$url")
  hash=$(nix-hash --to-sri --type sha256 "$source_path")

  echo "  New SRI hash for $nix_platform: $hash"

  # Update the hash and URL for the specific platform using sed.
  sed -E -i '/\s*'"$nix_platform"' = fetchurl \{/,/};/ s|(hash = ")([^"]*)(";)|\1'"$hash"'\3|' "$DEFAULT_NIX_FILE"
  sed -E -i '/\s*'"$nix_platform"' = fetchurl \{/,/};/ s|(url = ")([^"]*)(";)|\1'"$url"'\3|' "$DEFAULT_NIX_FILE"

  echo "Updated $nix_platform in $DEFAULT_NIX_FILE"
done

echo "Successfully updated $DEFAULT_NIX_FILE to version $latest_version_str"
# chmod +x "$DEFAULT_NIX_FILE" # Not typically needed for .nix files