#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git coreutils gnused gawk python3 nix

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
DEFAULT_NIX="$REPO_ROOT/pkgs/rtk/default.nix"
INSTALLABLE="path:$REPO_ROOT#rtk"

if [[ -n "${RTK_VERSION_OVERRIDE:-}" ]]; then
  target_version="${RTK_VERSION_OVERRIDE#v}"
else
  echo "Fetching latest release from rtk-ai/rtk..."
  target_version="$(
    git ls-remote --tags --refs https://github.com/rtk-ai/rtk.git \
      | awk '$2 ~ /^refs\/tags\/v[0-9]+\.[0-9]+\.[0-9]+$/ { print $2 }' \
      | sed 's#^refs/tags/v##' \
      | sort -Vr \
      | head -n1
  )"
fi

python3 - "$DEFAULT_NIX" "$target_version" "${RTK_REFRESH_HASHES:-0}" <<'PYTHON'
import json
from pathlib import Path
import re
import subprocess
import sys

path = Path(sys.argv[1])
version = sys.argv[2]
refresh = sys.argv[3] in {"1", "true", "yes", "y"}
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
    sys.exit(f"Error: invalid release version: {version!r}")

text = path.read_text()
version_pattern = re.compile(r'(version = ")[^"]+(";)')
current = version_pattern.search(text)
if current is None:
    sys.exit("Error: version not found in default.nix")

source_pattern = re.compile(
    r'(?P<prefix>asset = "(?P<asset>[^"]+)";\s+hash = ")'
    r'(?P<hash>[^"]*)(?P<suffix>";)'
)
sources = list(source_pattern.finditer(text))
if not sources:
    sys.exit("Error: release assets not found in default.nix")

current_version = current.group(0).split('"')[1]
print(f"Current version: {current_version}", flush=True)
print(f"Target version: {version}", flush=True)
hashes_complete = all(
    re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", source["hash"])
    and source["hash"] != "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    for source in sources
)
if version == current_version and hashes_complete and not refresh:
    print("Already on target version; set RTK_REFRESH_HASHES=1 to refresh hashes.")
    sys.exit(0)

hashes = {}
for source in sources:
    asset = source["asset"]
    print(f"Fetching {asset}...", flush=True)
    url = f"https://github.com/rtk-ai/rtk/releases/download/v{version}/{asset}"
    result = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", "--hash-type", "sha256", url],
        check=True, stdout=subprocess.PIPE, text=True,
    )
    hashes[asset] = json.loads(result.stdout)["hash"]

updated = source_pattern.sub(
    lambda match: match["prefix"] + hashes[match["asset"]] + match["suffix"], text
)
updated = version_pattern.sub(
    lambda match: match[1] + version + match[2], updated, count=1
)
path.write_text(updated)
print(f"Updated {path} to {version}")
PYTHON

case "${RTK_UPDATE_VERIFY:-0}" in
  1|true|yes|y)
    nix build --no-link --no-write-lock-file "$INSTALLABLE"
    ;;
esac
