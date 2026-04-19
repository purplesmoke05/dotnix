#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl git coreutils gnused nix python3

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
DEFAULT_NIX="$REPO_ROOT/pkgs/limux/default.nix"

if [[ ! -f "$DEFAULT_NIX" ]]; then
  echo "Error: $DEFAULT_NIX not found." >&2
  exit 1
fi

current_version=$(grep -m1 'version = "' "$DEFAULT_NIX" | sed 's/.*"\([^"]*\)".*/\1/')
echo "Current version: ${current_version:-<unknown>}"

if [[ -n "${LIMUX_VERSION_OVERRIDE:-}" ]]; then
  latest_tag="${LIMUX_VERSION_OVERRIDE#v}"
  echo "Using override version: v${latest_tag}"
else
  echo "Fetching latest release from am-will/limux..."
  representative_artifact_tmpl="limux-%s-linux-x86_64.tar.gz"

  latest_tag=$(
    git ls-remote --tags --refs https://github.com/am-will/limux.git \
    | awk '$2 ~ /^refs\/tags\/v[0-9]+\.[0-9]+\.[0-9]+$/ { print $2 }' \
    | sed 's#^refs/tags/v##' \
    | sort -Vr \
    | while read -r candidate; do
        artifact=$(printf "$representative_artifact_tmpl" "$candidate")
        url="https://github.com/am-will/limux/releases/download/v${candidate}/${artifact}"
        if curl -fsIL "$url" >/dev/null; then
          echo "$candidate"
          break
        fi
      done
  )

  if [[ -z "$latest_tag" ]]; then
    echo "Error: unable to determine latest release." >&2
    exit 1
  fi

  echo "Latest release: v${latest_tag}"
fi

if [[ "$latest_tag" == "$current_version" ]]; then
  echo "Already on latest version; hash will be refreshed."
fi

artifact="limux-${latest_tag}-linux-x86_64.tar.gz"
url="https://github.com/am-will/limux/releases/download/v${latest_tag}/${artifact}"

echo "Prefetching artifact: ${artifact}"
new_hash=$(nix-prefetch-url --type sha256 "$url")
echo "  -> $new_hash"

echo "Updating ${DEFAULT_NIX}..."

DEFAULT_NIX="$DEFAULT_NIX" \
LATEST_TAG="$latest_tag" \
NEW_HASH="$new_hash" \
python3 <<'PY'
import os
import pathlib
import re

default_nix = pathlib.Path(os.environ["DEFAULT_NIX"])
latest = os.environ["LATEST_TAG"]
new_hash = os.environ["NEW_HASH"]

text = default_nix.read_text()

text, count = re.subn(r'version = "[^"]*";', f'version = "{latest}";', text, count=1)
if count == 0:
    raise SystemExit("Failed to update version field in default.nix")

text, count = re.subn(r'sha256 = "[^"]*";', f'sha256 = "{new_hash}";', text, count=1)
if count == 0:
    raise SystemExit("Failed to update sha256 field in default.nix")

default_nix.write_text(text)
PY

echo "Update complete."
