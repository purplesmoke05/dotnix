#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl git coreutils gnused python3 nix

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
DEFAULT_NIX="$REPO_ROOT/pkgs/orca-ide/default.nix"
INSTALLABLE="path:$REPO_ROOT#orca-ide"

if [[ -n "${ORCA_IDE_VERSION_OVERRIDE:-}" ]]; then
  target_version="${ORCA_IDE_VERSION_OVERRIDE#v}"
else
  echo "Fetching latest release from stablyai/orca..."
  # Use the latest-release endpoint instead of the highest git tag because the repository also publishes prereleases and separate product lines such as mobile-android-v*. / リポジトリは prerelease や mobile-android-v* のような別系統タグも公開するため、最高タグではなく latest release endpoint を使う。
  target_tag="$(
    curl -fsSL https://api.github.com/repos/stablyai/orca/releases/latest \
      | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tag_name",""))'
  )"
  if [[ ! "$target_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: unexpected latest release tag: ${target_tag:-<empty>}" >&2
    exit 1
  fi
  target_version="${target_tag#v}"
fi

python3 - "$DEFAULT_NIX" "$target_version" "${ORCA_IDE_REFRESH_HASHES:-0}" <<'PYTHON'
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

# Match the per-architecture hashes in the `hashes` attribute. / `hashes` 属性の arch 別ハッシュを拾う。
hash_pattern = re.compile(
    r'(?P<prefix>(?P<arch>amd64|arm64) = ")'
    r'(?P<hash>[^"]*)(?P<suffix>";)'
)
hashes = list(hash_pattern.finditer(text))
if not hashes:
    sys.exit("Error: per-architecture hashes not found in default.nix")

current_version = current.group(0).split('"')[1]
print(f"Current version: {current_version}", flush=True)
print(f"Target version: {version}", flush=True)

hashes_complete = all(
    re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", entry["hash"])
    and entry["hash"] != "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    for entry in hashes
)
if version == current_version and hashes_complete and not refresh:
    print("Already on target version; set ORCA_IDE_REFRESH_HASHES=1 to refresh hashes.")
    sys.exit(0)

new_hashes = {}
for entry in hashes:
    arch = entry["arch"]
    url = (
        "https://github.com/stablyai/orca/releases/download/"
        f"v{version}/orca-ide_{version}_{arch}.deb"
    )
    print(f"Prefetching {arch} package...", flush=True)
    result = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", "--hash-type", "sha256", url],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )
    new_hashes[arch] = json.loads(result.stdout)["hash"]

# Write only after every download succeeds. / すべてのダウンロードが成功してから書き込む。
updated = hash_pattern.sub(
    lambda match: match["prefix"] + new_hashes[match["arch"]] + match["suffix"],
    text,
)
updated = version_pattern.sub(
    lambda match: match[1] + version + match[2], updated, count=1
)
path.write_text(updated)
print(f"Updated {path} to {version}")
PYTHON

case "${ORCA_IDE_UPDATE_VERIFY:-0}" in
  1|true|yes|y)
    echo "Verifying updated package..."
    nix build --no-link --no-write-lock-file "$INSTALLABLE"
    ;;
esac

echo "Update complete: v${target_version}"
