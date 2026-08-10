#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq git coreutils gnused gnutar gzip nodejs_22 prefetch-npm-deps nix perl

set -euo pipefail

RELEASE_BASE_URL="https://pub-728493de92a943e2a9b2d17b4719f318.r2.dev"
RELEASE_MANIFEST_URL="$RELEASE_BASE_URL/latest.json"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
PACKAGE_DIR="$REPO_ROOT/pkgs/prime-agent"
DEFAULT_NIX="$PACKAGE_DIR/default.nix"
PACKAGE_JSON="$PACKAGE_DIR/package.json"
PACKAGE_LOCK="$PACKAGE_DIR/package-lock.json"
INSTALLABLE="path:$REPO_ROOT#prime-agent"

current_version="$(sed -n 's/^\s*version = "\([^"]*\)";/\1/p' "$DEFAULT_NIX" | head -n1)"
echo "Current version: ${current_version:-<unknown>}"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

manifest_file="$tmpdir/latest.json"
echo "Fetching Prime Agent release metadata..."
curl -fsSL "$RELEASE_MANIFEST_URL" -o "$manifest_file"

if [[ -n "${PRIME_AGENT_VERSION_OVERRIDE:-}" ]]; then
  target_version="${PRIME_AGENT_VERSION_OVERRIDE#v}"
  echo "Using override version: $target_version"
else
  target_version="$(jq -r '.version // empty | sub("^v"; "")' "$manifest_file")"
  if [[ -z "$target_version" ]]; then
    echo "Error: failed to resolve latest Prime Agent version." >&2
    exit 1
  fi
  echo "Latest version: $target_version"
fi

tarball_path="$(jq -r --arg version "v$target_version" '
  if .version == $version then .tarball // empty else empty end
' "$manifest_file")"
src_sha256="$(jq -r --arg file "prime-agent-$target_version.tgz" '
  .tarballs[]? | select(.file == $file) | .sha256
' "$manifest_file")"

if [[ -z "$tarball_path" || -z "$src_sha256" ]]; then
  echo "Error: release metadata for $target_version was not found." >&2
  echo "Set PRIME_AGENT_VERSION_OVERRIDE only after the release appears in latest.json." >&2
  exit 1
fi

tarball_url="$RELEASE_BASE_URL/${tarball_path#/}"
src_hash="$(nix hash convert --hash-algo sha256 --to sri "$src_sha256")"
archive="$tmpdir/prime-agent.tgz"
src_dir="$tmpdir/src"
work_dir="$tmpdir/work"

echo "Downloading $tarball_url..."
curl -fsSL "$tarball_url" -o "$archive"
printf '%s  %s\n' "$src_sha256" "$archive" | sha256sum -c -

mkdir -p "$src_dir" "$work_dir"
tar -xzf "$archive" -C "$src_dir"
if [[ ! -f "$src_dir/package/package.json" ]]; then
  echo "Error: package.json not found in Prime Agent release." >&2
  exit 1
fi

jq '{
  name,
  version,
  description,
  type,
  bin,
  main,
  dependencies,
  optionalDependencies,
  engines
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

echo "Calculating npmDepsHash..."
npm_deps_hash="$(prefetch-npm-deps "$work_dir/package-lock.json")"
echo "Source hash: $src_hash"
echo "npmDepsHash: $npm_deps_hash"

install -m 0644 "$work_dir/package.json" "$PACKAGE_JSON"
install -m 0644 "$work_dir/package-lock.json" "$PACKAGE_LOCK"

PRIME_AGENT_VERSION="$target_version" \
PRIME_AGENT_SRC_HASH="$src_hash" \
PRIME_AGENT_NPM_DEPS_HASH="$npm_deps_hash" \
perl -0pi -e '
  s/(version = ")[^"]*(";)/$1$ENV{PRIME_AGENT_VERSION}$2/s or die "failed to update version\n";
  s/(hash = ")[^"]*(";)/$1$ENV{PRIME_AGENT_SRC_HASH}$2/s or die "failed to update source hash\n";
  s/(npmDepsHash = ")[^"]*(";)/$1$ENV{PRIME_AGENT_NPM_DEPS_HASH}$2/s or die "failed to update npmDepsHash\n";
' "$DEFAULT_NIX"

if [[ "${PRIME_AGENT_UPDATE_VERIFY:-0}" == "1" ]]; then
  echo "Verifying updated package..."
  nix build --no-link --no-write-lock-file "$INSTALLABLE"
else
  echo "Skipping package build verification. Set PRIME_AGENT_UPDATE_VERIFY=1 to enable it."
fi

echo "Update complete: $target_version"
