#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl git coreutils gnused nix python3

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
DEFAULT_NIX="$REPO_ROOT/pkgs/codex/default.nix"

if [[ ! -f "$DEFAULT_NIX" ]]; then
  echo "Error: $DEFAULT_NIX not found." >&2
  exit 1
fi

current_version=$(grep -m1 'version = "' "$DEFAULT_NIX" | sed 's/.*"\([^"]*\)".*/\1/')
echo "Current version: ${current_version:-<unknown>}"

release_channel="${CODEX_RELEASE_CHANNEL:-stable}"
case "$release_channel" in
  stable|alpha)
    ;;
  *)
    echo "Error: CODEX_RELEASE_CHANNEL must be 'stable' or 'alpha'." >&2
    exit 1
    ;;
esac

if [[ -n "${CODEX_VERSION_OVERRIDE:-}" ]]; then
  latest_tag="${CODEX_VERSION_OVERRIDE#rust-v}"
  echo "Using override version: rust-v${latest_tag}"
else
  echo "Fetching latest ${release_channel} release from openai/codex..."
  if [[ "$release_channel" == "stable" ]]; then
    tag_pattern='refs/tags/rust-v[0-9]+[.][0-9]+[.][0-9]+$'
  else
    tag_pattern='refs/tags/rust-v[0-9]+[.][0-9]+[.][0-9]+-alpha[.][0-9]+$'
  fi

  representative_artifact="codex-x86_64-unknown-linux-gnu.tar.gz"
  latest_tag=$(
    git ls-remote --tags --refs https://github.com/openai/codex.git \
    | awk -v pattern="$tag_pattern" '$2 ~ pattern { print $2 }' \
    | sed 's#^refs/tags/rust-v##' \
    | sort -Vr \
    | while read -r candidate; do
        url="https://github.com/openai/codex/releases/download/rust-v${candidate}/${representative_artifact}"
        if curl -fsIL "$url" >/dev/null; then
          echo "$candidate"
          break
        fi
      done
  )

  if [[ -z "$latest_tag" ]]; then
    echo "Error: unable to determine latest ${release_channel} release." >&2
    exit 1
  fi

  echo "Latest ${release_channel} release: rust-v${latest_tag}"
fi

if [[ "$latest_tag" == "$current_version" ]]; then
  echo "Already on latest version; hashes will be refreshed."
fi

artifacts=(
  "x86_64-linux codex-x86_64-unknown-linux-gnu.tar.gz"
  "aarch64-linux codex-aarch64-unknown-linux-gnu.tar.gz"
  "x86_64-darwin codex-x86_64-apple-darwin.tar.gz"
  "aarch64-darwin codex-aarch64-apple-darwin.tar.gz"
)

declare -A hashes

for entry in "${artifacts[@]}"; do
  read -r system artifact <<<"$entry"
  url="https://github.com/openai/codex/releases/download/rust-v${latest_tag}/${artifact}"
  echo "Prefetching ${system} artifact: ${artifact}"
  base32_hash=$(nix-prefetch-url --type sha256 "$url")
  sri_hash=$(nix hash convert --hash-algo sha256 --from nix32 --to sri "$base32_hash")
  hashes[$system]="$sri_hash"
  echo "  -> $sri_hash"
done

echo "Updating ${DEFAULT_NIX}..."

hash_json="{"
sep=""
for entry in "${artifacts[@]}"; do
  read -r system _ <<<"$entry"
  hash="${hashes[$system]}"
  hash_json+="${sep}\"${system}\":\"${hash}\""
  sep=","
done
hash_json+="}"

DEFAULT_NIX="$DEFAULT_NIX" \
LATEST_TAG="$latest_tag" \
HASHES_JSON="$hash_json" \
python3 <<'PY'
import json
import os
import pathlib
import re

default_nix = pathlib.Path(os.environ["DEFAULT_NIX"])
latest = os.environ["LATEST_TAG"]
hashes = json.loads(os.environ["HASHES_JSON"])

text = default_nix.read_text()

text, count = re.subn(r'version = "[^"]*";', f'version = "{latest}";', text, count=1)
if count == 0:
    raise SystemExit("Failed to update version field in default.nix")

for system, new_hash in hashes.items():
    pattern = r'(%s = \{.*?sha256 = ")([^\"]*)(";)' % re.escape(system)
    text, count = re.subn(
        pattern,
        lambda match: f"{match.group(1)}{new_hash}{match.group(3)}",
        text,
        count=1,
        flags=re.S,
    )
    if count == 0:
        raise SystemExit(f"Failed to update hash for {system}")

default_nix.write_text(text)
PY

echo "Update complete."
