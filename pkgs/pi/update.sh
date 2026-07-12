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
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

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

package_files_need_refresh() {
  DEFAULT_NIX="$DEFAULT_NIX" \
  PACKAGE_JSON="$PACKAGE_JSON" \
  PACKAGE_LOCK="$PACKAGE_LOCK" \
  TARGET_VERSION="$target_version" \
  FAKE_HASH="$FAKE_HASH" \
  python3 <<'PY'
import json
import os
import pathlib
import re
import sys

default_nix = pathlib.Path(os.environ["DEFAULT_NIX"])
package_json = pathlib.Path(os.environ["PACKAGE_JSON"])
package_lock = pathlib.Path(os.environ["PACKAGE_LOCK"])
target = os.environ["TARGET_VERSION"]
fake_hash = os.environ["FAKE_HASH"]

if not default_nix.exists() or not package_json.exists() or not package_lock.exists():
    sys.exit(0)

text = default_nix.read_text()
src_hash = re.search(r'^\s*hash\s*=\s*"([^"]*)";', text, flags=re.M)
npm_deps_hash = re.search(r'^\s*npmDepsHash\s*=\s*"([^"]*)";', text, flags=re.M)

for match in (src_hash, npm_deps_hash):
    if match is None or match.group(1) in ("", fake_hash):
        sys.exit(0)

with package_json.open() as f:
    package_json_data = json.load(f)
with package_lock.open() as f:
    package_lock_data = json.load(f)

if package_json_data.get("version") != target:
    sys.exit(0)

if package_lock_data.get("version") != target:
    sys.exit(0)

root_package = package_lock_data.get("packages", {}).get("", {})
if root_package.get("version") != target:
    sys.exit(0)

sys.exit(1)
PY
}

if [[ "$target_version" == "$current_version" ]] && ! is_truthy "${PI_REFRESH_HASHES:-0}"; then
  if package_files_need_refresh; then
    echo "Already on target version, but hashes or package files need refresh."
  else
    echo "Already on latest version; nothing to update."
    echo "Set PI_REFRESH_HASHES=1 to recompute hashes and lockfile."
    exit 0
  fi
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

if is_truthy "${PI_UPDATE_VERIFY:-0}"; then
  echo "Verifying updated package..."
  nix build --no-link --no-write-lock-file "$INSTALLABLE"
else
  echo "Skipping package build verification. Set PI_UPDATE_VERIFY=1 to enable it."
fi

echo "Update complete: $target_version"
