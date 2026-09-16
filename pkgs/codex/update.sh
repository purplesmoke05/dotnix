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

  representative_artifact="codex-x86_64-unknown-linux-musl.tar.gz"
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

python3 - "$DEFAULT_NIX" "$latest_tag" "${CODEX_REFRESH_HASHES:-0}" <<'PYTHON'
import json
from pathlib import Path
import re
import subprocess
import sys

path = Path(sys.argv[1])
version = sys.argv[2]
refresh = sys.argv[3] in {"1", "true", "yes", "y"}
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:-alpha\.[0-9]+)?", version):
    sys.exit(f"Error: invalid release version: {version!r}")

text = path.read_text()
version_pattern = re.compile(r'(version = ")(?P<version>[^"]+)(";)')
current = version_pattern.search(text)
if current is None:
    sys.exit("Error: version not found in default.nix")

# Read both CLI and host assets from the package definition. / 本体と host の配布物をパッケージ定義から取得する。
source_pattern = re.compile(
    r'(?P<prefix>\b(?:artifact|hostArtifact) = "(?P<asset>[^"]+)";'
    r'\s+(?:sha256|hostSha256) = ")(?P<hash>[^"]*)(?P<suffix>";)'
)
sources = list(source_pattern.finditer(text))
if not sources:
    sys.exit("Error: release artifacts not found in default.nix")

hashes_complete = all(
    re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", source["hash"])
    and source["hash"] != "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    for source in sources
)
if version == current["version"] and hashes_complete and not refresh:
    print("Already on target version; set CODEX_REFRESH_HASHES=1 to refresh hashes.")
    sys.exit(0)

hashes = {}
for source in sources:
    asset = source["asset"]
    print(f"Prefetching {asset}...", flush=True)
    url = f"https://github.com/openai/codex/releases/download/rust-v{version}/{asset}"
    result = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", "--hash-type", "sha256", url],
        check=True, stdout=subprocess.PIPE, text=True,
    )
    hashes[asset] = json.loads(result.stdout)["hash"]

# Write only after every download succeeds. / すべてのダウンロードが成功してから書き込む。
updated = source_pattern.sub(
    lambda match: match["prefix"] + hashes[match["asset"]] + match["suffix"], text
)
updated = version_pattern.sub(
    lambda match: match[1] + version + match[3], updated, count=1
)
path.write_text(updated)
print(f"Updated {path} to {version}")
PYTHON
