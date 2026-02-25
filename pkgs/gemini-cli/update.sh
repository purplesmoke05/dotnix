#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq common-updater-scripts coreutils gnused nix gh nix-prefetch-github prefetch-npm-deps

set -euo pipefail

# The Nix file to update
DEFAULT_NIX_FILE="$(dirname "$0")/default.nix"
REPO_OWNER="google-gemini"
REPO_NAME="gemini-cli"

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
  echo "Already on latest version; refreshing hashes."
fi

echo "Updating from $currentVersion to $latestVersion..."

# Update version in default.nix
sed -i 's/version = "[^"]*";/version = "'${latestVersion}'";/' "$DEFAULT_NIX_FILE"

# Update source hash and npmDepsHash
echo "Fetching source metadata..."
prefetchData=$(nix-prefetch-github ${REPO_OWNER} ${REPO_NAME} --rev "${latestRelease}" 2>/dev/null)
newHash=$(echo "$prefetchData" | jq -r '.hash')

if [[ -z "$newHash" || "$newHash" == "null" ]]; then
  echo "Error: Could not fetch source metadata. Aborting."
  exit 1
fi

echo "New source hash: $newHash"
sed -i 's|hash = "[^"]*";|hash = "'${newHash}'";|' "$DEFAULT_NIX_FILE"

tmpdir=$(mktemp -d)
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

srcArchive="$tmpdir/src.tar.gz"
srcDir="$tmpdir/src"
mkdir -p "$srcDir"

echo "Downloading source archive for lockfile..."
curl -L -sSf "https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/tags/${latestRelease}.tar.gz" -o "$srcArchive"
tar -xzf "$srcArchive" -C "$srcDir" --strip-components=1

lockFilePath="$srcDir/package-lock.json"
if [[ ! -f "$lockFilePath" ]]; then
  echo "Error: package-lock.json not found in source archive."
  exit 1
fi

echo "Calculating npmDepsHash from lockfile..."
npmDepsHash=$(prefetch-npm-deps "$lockFilePath")
if [[ -z "$npmDepsHash" ]]; then
  echo "Error: Could not calculate npmDepsHash."
  exit 1
fi

echo "New npmDepsHash: $npmDepsHash"
sed -i 's|npmDepsHash = "[^"]*";|npmDepsHash = "'${npmDepsHash}'";|' "$DEFAULT_NIX_FILE"

echo "Successfully updated gemini-cli to version $latestVersion!"
echo "Skipped post-update verification build for speed."

echo "Update complete!"
