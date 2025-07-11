#!/usr/bin/env bash
set -euo pipefail

# Get the latest testnet release version
echo "Fetching latest Sui testnet release..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/MystenLabs/sui/releases | jq -r '.[] | select(.tag_name | startswith("testnet-v")) | .tag_name' | head -n1 | sed 's/testnet-v//')

echo "Latest version: $LATEST_VERSION"

# Update version in default.nix
sed -i "s/version = \"[^\"]*\"/version = \"$LATEST_VERSION\"/" default.nix

# Get source hash
echo "Fetching source hash..."
SRC_HASH=$(nix-prefetch-url --unpack "https://github.com/MystenLabs/sui/archive/testnet-v$LATEST_VERSION.tar.gz" 2>/dev/null | tail -n1)
SRI_HASH=$(nix hash to-sri --type sha256 "$SRC_HASH")

# Update source hash
sed -i "s|hash = \"sha256-[^\"]*\"|hash = \"$SRI_HASH\"|" default.nix

echo "Updated to version $LATEST_VERSION"
echo "Source hash: $SRI_HASH"

# Try to build and get cargo hash
echo "Building to get cargo hash..."
BUILD_OUTPUT=$(nix-build -E 'with import <nixpkgs> {}; callPackage ./default.nix {}' 2>&1 || true)

if echo "$BUILD_OUTPUT" | grep -q "got:"; then
    CARGO_HASH=$(echo "$BUILD_OUTPUT" | grep -A1 "got:" | tail -n1 | xargs)
    echo "Cargo hash: $CARGO_HASH"
    
    # Update cargo hash
    sed -i "s|cargoHash = \"sha256-[^\"]*\"|cargoHash = \"$CARGO_HASH\"|" default.nix
    
    echo "Successfully updated all hashes!"
else
    echo "Could not determine cargo hash automatically. You'll need to:"
    echo "1. Set cargoHash to an empty string or dummy value"
    echo "2. Run 'nix-build -E \"with import <nixpkgs> {}; callPackage ./default.nix {}\"'"
    echo "3. Copy the correct hash from the error message"
fi