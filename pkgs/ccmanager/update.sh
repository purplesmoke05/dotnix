#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq common-updater-scripts coreutils gnused nix gh

set -euo pipefail

# The Nix file to update
DEFAULT_NIX_FILE="$(dirname "$0")/default.nix"
REPO_OWNER="kbwo"
REPO_NAME="ccmanager"

# Get the current version from the default.nix file
currentVersion=$(sed -n 's/\s*version = "\([^"]*\)";/\1/p' "$DEFAULT_NIX_FILE" | head -n1 | tr -d '"')
echo "Current version in $DEFAULT_NIX_FILE: $currentVersion"

# Get the latest release from GitHub
echo "Fetching latest release from GitHub..."
latestRelease=$(gh api repos/${REPO_OWNER}/${REPO_NAME}/releases/latest --jq '.tag_name' 2>/dev/null || echo "")

if [[ -z "$latestRelease" ]]; then
  echo "Error: Could not fetch latest release from GitHub. Aborting."
  exit 1
fi

# Remove 'v' prefix if present
latestVersion="${latestRelease#v}"

echo "Latest version on GitHub: $latestVersion"

# Check if we need to update
if [[ "$latestVersion" == "$currentVersion" ]]; then
  echo "Already up to date!"
  exit 0
fi

echo "Updating from $currentVersion to $latestVersion..."

# Update version in default.nix
sed -i 's/version = "[^"]*";/version = "'${latestVersion}'";/' "$DEFAULT_NIX_FILE"

# Update rev in default.nix (assuming tag format is either 'v${version}' or '${version}')
sed -i 's/rev = "[^"]*";/rev = "'${latestRelease}'";/' "$DEFAULT_NIX_FILE"

# Update the source hash
echo "Fetching new source hash..."
newHash=$(nix-prefetch-github ${REPO_OWNER} ${REPO_NAME} --rev ${latestRelease} 2>/dev/null | jq -r '.hash')

if [[ -z "$newHash" || "$newHash" == "null" ]]; then
  echo "Error: Could not fetch source hash. Aborting."
  exit 1
fi

echo "New source hash: $newHash"
sed -i 's/hash = "[^"]*";/hash = "'${newHash}'";/' "$DEFAULT_NIX_FILE"

# Now we need to update the npmDepsHash
echo "Building to get new npmDepsHash..."
echo "This will fail, but we'll get the correct hash from the error message"

# Create a temporary file to capture the error
tmpfile=$(mktemp)

# Try to build and capture the error
if nix build .#ccmanager-base 2>&1 | tee "$tmpfile"; then
  echo "Build succeeded unexpectedly. The npmDepsHash might already be correct."
else
  # Extract the correct hash from the error message
  correctHash=$(grep -o 'got:[[:space:]]*sha256-[^[:space:]]*' "$tmpfile" | sed 's/got:[[:space:]]*//')
  
  if [[ -n "$correctHash" ]]; then
    echo "Updating npmDepsHash to: $correctHash"
    sed -i 's/npmDepsHash = "[^"]*";/npmDepsHash = "'${correctHash}'";/' "$DEFAULT_NIX_FILE"
    
    # Try building again to verify
    echo "Verifying the update..."
    if nix build .#ccmanager-base; then
      echo "Successfully updated ccmanager to version $latestVersion!"
    else
      echo "Error: Build still failing after hash update. Please check manually."
      exit 1
    fi
  else
    echo "Error: Could not extract correct npmDepsHash from error message."
    echo "Please update it manually."
    exit 1
  fi
fi

# Clean up
rm -f "$tmpfile"

echo "Update complete!"