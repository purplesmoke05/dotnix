#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git coreutils gnused nix python3 curl

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
DEFAULT_NIX="$REPO_ROOT/pkgs/opencode/default.nix"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

if [[ ! -f "$DEFAULT_NIX" ]]; then
  echo "Error: $DEFAULT_NIX not found." >&2
  exit 1
fi

current_version=$(grep -m1 'version = "' "$DEFAULT_NIX" | sed 's/.*"\([^"]*\)".*/\1/')
echo "Current version: ${current_version:-<unknown>}"

if [[ -n "${OPENCODE_VERSION_OVERRIDE:-}" ]]; then
  latest_tag="${OPENCODE_VERSION_OVERRIDE#v}"
  echo "Using override version: v${latest_tag}"
else
  echo "Fetching latest release from anomalyco/opencode..."
  # Use the GitHub "latest release" endpoint rather than the highest git tag,
  # because the repository also carries tags for other product lines (e.g. vscode-v*, v2.0.x).
  latest_tag=$(
    curl -fsSL https://api.github.com/repos/anomalyco/opencode/releases/latest \
      | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tag_name","").lstrip("v"))'
  )

  if [[ -z "$latest_tag" ]]; then
    echo "Error: unable to determine latest release." >&2
    exit 1
  fi

  echo "Latest release: v${latest_tag}"
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

# A previous interrupted run may leave the fake hash behind; refresh when detected.
hashes_need_refresh() {
  DEFAULT_NIX="$DEFAULT_NIX" \
  FAKE_HASH="$FAKE_HASH" \
  python3 <<'PY'
import os
import pathlib
import sys

text = pathlib.Path(os.environ["DEFAULT_NIX"]).read_text()
sys.exit(0 if os.environ["FAKE_HASH"] in text else 1)
PY
}

if [[ "$latest_tag" == "$current_version" ]] && ! is_truthy "${OPENCODE_REFRESH_HASHES:-0}"; then
  if hashes_need_refresh; then
    echo "Already on target version, but hashes need refresh."
  else
    echo "Already on latest version; nothing to update."
    echo "Set OPENCODE_REFRESH_HASHES=1 to recompute hashes."
    exit 0
  fi
fi

echo "Prefetching source tarball for v${latest_tag}..."
src_url="https://github.com/anomalyco/opencode/archive/refs/tags/v${latest_tag}.tar.gz"
base32_hash=$(nix-prefetch-url --unpack "$src_url")
src_hash=$(nix hash convert --hash-algo sha256 --from nix32 --to sri "$base32_hash")
echo "  src -> $src_hash"

DEFAULT_NIX="$DEFAULT_NIX" \
LATEST_TAG="$latest_tag" \
SRC_HASH="$src_hash" \
FAKE_HASH="$FAKE_HASH" \
python3 <<'PY'
import os
import pathlib
import re

default_nix = pathlib.Path(os.environ["DEFAULT_NIX"])
latest = os.environ["LATEST_TAG"]
src_hash = os.environ["SRC_HASH"]
fake_hash = os.environ["FAKE_HASH"]

text = default_nix.read_text()

text, count = re.subn(r'version = "[^"]*";', f'version = "{latest}";', text, count=1)
if count == 0:
    raise SystemExit("Failed to update version field in default.nix")

text, count = re.subn(
    r'(src = fetchFromGitHub \{.*?hash = ")([^"]*)(")',
    lambda match: f"{match.group(1)}{src_hash}{match.group(3)}",
    text,
    count=1,
    flags=re.S,
)
if count == 0:
    raise SystemExit("Failed to update src hash in default.nix")

# Reset the fixed-output hash so the next build reveals the real one.
text, count = re.subn(
    r'(outputHash = ")([^"]*)(")',
    lambda match: f"{match.group(1)}{fake_hash}{match.group(3)}",
    text,
    count=1,
)
if count == 0:
    raise SystemExit("Failed to reset outputHash in default.nix")

default_nix.write_text(text)
PY

echo "Discovering node_modules fixed-output hash (builds the dependency derivation)..."
build_log=$(mktemp)
nix build --no-link --no-write-lock-file "path:$REPO_ROOT#opencode" >"$build_log" 2>&1 || true

new_output_hash=$(sed -n 's/.*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' "$build_log" | tail -n1)
if [[ -z "$new_output_hash" ]]; then
  echo "Error: could not determine node_modules hash. Build log follows:" >&2
  cat "$build_log" >&2
  exit 1
fi
echo "  node_modules -> $new_output_hash"

DEFAULT_NIX="$DEFAULT_NIX" \
OUTPUT_HASH="$new_output_hash" \
python3 <<'PY'
import os
import pathlib
import re

default_nix = pathlib.Path(os.environ["DEFAULT_NIX"])
text = default_nix.read_text()

text, count = re.subn(
    r'(outputHash = ")([^"]*)(")',
    lambda match: f"{match.group(1)}{os.environ['OUTPUT_HASH']}{match.group(3)}",
    text,
    count=1,
)
if count == 0:
    raise SystemExit("Failed to update outputHash in default.nix")

default_nix.write_text(text)
PY

if is_truthy "${OPENCODE_UPDATE_VERIFY:-1}"; then
  echo "Verifying updated package..."
  nix build --no-link --no-write-lock-file "path:$REPO_ROOT#opencode"
else
  echo "Skipping verification build. Set OPENCODE_UPDATE_VERIFY=1 to enable it."
fi

echo "Update complete: v${latest_tag}"
