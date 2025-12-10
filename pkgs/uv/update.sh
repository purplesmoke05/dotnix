#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq common-updater-scripts coreutils gnused nix python3

set -euo pipefail

# The Nix file to update
DEFAULT_NIX_FILE="$(dirname "$0")/default.nix"

# Get latest version
echo "Fetching latest version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/astral-sh/uv/releases/latest | jq -r .tag_name | sed 's/^v//')
echo "Latest version: $LATEST_VERSION"

# Platforms mapping
declare -A PLATFORMS=(
    ["x86_64-linux"]="x86_64-unknown-linux-gnu"
    ["aarch64-linux"]="aarch64-unknown-linux-gnu"
    ["x86_64-darwin"]="x86_64-apple-darwin"
    ["aarch64-darwin"]="aarch64-apple-darwin"
)

# Collect hashes
echo "Collecting hashes..."
HASHES_JSON="{"
SEP=""

for platform in "${!PLATFORMS[@]}"; do
    suffix="${PLATFORMS[$platform]}"
    url="https://github.com/astral-sh/uv/releases/download/${LATEST_VERSION}/uv-${suffix}.tar.gz"
    
    echo "Prefetching $platform..."
    # prefetch-url often outputs the hash to stdout, but we want sri hash
    hash=$(nix-prefetch-url "$url" 2>/dev/null)
    sri_hash=$(nix hash to-sri --type sha256 "$hash")
    echo "  $platform: $sri_hash"
    
    HASHES_JSON="${HASHES_JSON}${SEP}\"${platform}\": \"${sri_hash}\""
    SEP=","
done
HASHES_JSON="${HASHES_JSON}}"

echo "Updating default.nix..."

DEFAULT_NIX="$DEFAULT_NIX_FILE" \
LATEST_VERSION="$LATEST_VERSION" \
HASHES_JSON="$HASHES_JSON" \
python3 <<'PY'
import json
import os
import pathlib
import re

default_nix = pathlib.Path(os.environ["DEFAULT_NIX"])
latest = os.environ["LATEST_VERSION"]
hashes = json.loads(os.environ["HASHES_JSON"])

text = default_nix.read_text()

# Update version
text = re.sub(r'version = "[^"]*";', f'version = "{latest}";', text, count=1)

# Update hashes
for platform, new_hash in hashes.items():
    # Look for platform block and update the hash inside it
    # We assume standard formatting: platform = { ... hash = "..."; ... };
    # We use a regex that matches the platform key up to the hash
    
    # Regex explanation:
    # 1. (platform\s*=\s*\{.*?hash\s*=\s*")          -> Capture group 1: platform = { ... (lazy match until hash)
    # 2. [^"]*                                       -> The hash value to replace
    # 3. (")                                         -> Capture group 2: The closing quote
    
    pattern = r'(%s\s*=\s*\{.*?hash\s*=\s*")[^"]*(")' % re.escape(platform)
    
    text, count = re.subn(
        pattern,
        lambda m: f"{m.group(1)}{new_hash}{m.group(2)}",
        text,
        count=1,
        flags=re.DOTALL # Make . match newlines so we can search across lines
    )
    
    if count == 0:
        print(f"Warning: Could not update hash for {platform}")

default_nix.write_text(text)
PY

echo "Update complete!"