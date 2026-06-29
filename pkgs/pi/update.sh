#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq git coreutils gnused gnutar gzip nodejs_22 prefetch-npm-deps nix perl

set -euo pipefail

PACKAGE_NAME="@earendil-works/pi-coding-agent"
REGISTRY_URL="https://registry.npmjs.org/@earendil-works%2Fpi-coding-agent"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
PACKAGE_DIR="$REPO_ROOT/pkgs/pi"
DEFAULT_NIX="$PACKAGE_DIR/default.nix"
PACKAGE_JSON="$PACKAGE_DIR/package.json"
PACKAGE_LOCK="$PACKAGE_DIR/package-lock.json"
INSTALLABLE="path:$REPO_ROOT#pi"

if [[ ! -f "$DEFAULT_NIX" ]]; then
  echo "Error: $DEFAULT_NIX not found." >&2
  exit 1
fi

current_version="$(sed -n 's/^\s*version = "\([^"]*\)";/\1/p' "$DEFAULT_NIX" | head -n1)"
echo "Current version: ${current_version:-<unknown>}"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

metadata_file="$tmpdir/metadata.json"
echo "Fetching npm metadata for $PACKAGE_NAME..."
curl -fsSL "$REGISTRY_URL" -o "$metadata_file"

if [[ -n "${PI_VERSION_OVERRIDE:-}" ]]; then
  target_version="${PI_VERSION_OVERRIDE#v}"
  echo "Using override version: $target_version"
else
  target_version="$(jq -r '."dist-tags".latest // empty' "$metadata_file")"
  if [[ -z "$target_version" ]]; then
    echo "Error: failed to resolve latest npm version." >&2
    exit 1
  fi
  echo "Latest npm version: $target_version"
fi

if [[ "$(jq -r --arg version "$target_version" '.versions[$version] != null' "$metadata_file")" != "true" ]]; then
  echo "Error: version $target_version was not found in npm metadata." >&2
  exit 1
fi

if [[ "$target_version" == "$current_version" ]]; then
  echo "Already on latest version; hashes and lockfile will be refreshed."
fi

src_hash="$(jq -r --arg version "$target_version" '.versions[$version].dist.integrity // empty' "$metadata_file")"
tarball_url="$(jq -r --arg version "$target_version" '.versions[$version].dist.tarball // empty' "$metadata_file")"

if [[ -z "$src_hash" || "$src_hash" == "null" ]]; then
  echo "Error: dist.integrity not found for $target_version." >&2
  exit 1
fi

if [[ -z "$tarball_url" || "$tarball_url" == "null" ]]; then
  echo "Error: dist.tarball not found for $target_version." >&2
  exit 1
fi

echo "Source hash: $src_hash"

archive="$tmpdir/package.tgz"
src_dir="$tmpdir/src"
work_dir="$tmpdir/work"

echo "Downloading package tarball..."
curl -fsSL "$tarball_url" -o "$archive"
mkdir -p "$src_dir" "$work_dir"
tar -xzf "$archive" -C "$src_dir"

if [[ ! -f "$src_dir/package/package.json" ]]; then
  echo "Error: package.json not found in npm tarball." >&2
  exit 1
fi

jq '{
  name,
  version,
  description,
  type,
  license,
  bin,
  main,
  dependencies,
  optionalDependencies
} | with_entries(select(.value != null))' \
  "$src_dir/package/package.json" > "$work_dir/package.json"

echo "Generating package-lock.json..."
(
  cd "$work_dir"
  npm install \
    --package-lock-only \
    --ignore-scripts \
    --omit=dev \
    --no-audit \
    --no-fund
)

if [[ ! -f "$work_dir/package-lock.json" ]]; then
  echo "Error: npm did not create package-lock.json." >&2
  exit 1
fi

echo "Calculating npmDepsHash..."
npm_deps_hash="$(prefetch-npm-deps "$work_dir/package-lock.json")"
if [[ -z "$npm_deps_hash" ]]; then
  echo "Error: failed to calculate npmDepsHash." >&2
  exit 1
fi
echo "npmDepsHash: $npm_deps_hash"

echo "Updating package files..."
install -m 0644 "$work_dir/package.json" "$PACKAGE_JSON"
install -m 0644 "$work_dir/package-lock.json" "$PACKAGE_LOCK"

PI_VERSION="$target_version" \
PI_SRC_HASH="$src_hash" \
PI_NPM_DEPS_HASH="$npm_deps_hash" \
perl -0pi -e '
  s/(version = ")[^"]*(";)/$1$ENV{PI_VERSION}$2/s or die "failed to update version\n";
  s/(hash = ")[^"]*(";)/$1$ENV{PI_SRC_HASH}$2/s or die "failed to update source hash\n";
  s/(npmDepsHash = ")[^"]*(";)/$1$ENV{PI_NPM_DEPS_HASH}$2/s or die "failed to update npmDepsHash\n";
' "$DEFAULT_NIX"

echo "Verifying updated package..."
nix build --no-link --no-write-lock-file "$INSTALLABLE"

echo "Update complete: $target_version"
