#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
PKG_FILE="$REPO_ROOT/pkgs/codex/default.nix"

for tool in curl jq git nix-prefetch-url nix; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Error: required tool '$tool' not found in PATH." >&2
    exit 1
  fi
done

currentVersion=$(sed -n 's/^[[:space:]]*version = "\([^"]*\)";/\1/p' "$PKG_FILE" | head -n1)
echo "Current codex version in default.nix: ${currentVersion:-<none>}"

echo "Querying latest rust tag from openai/codex..."
latest_tag=$(git ls-remote --tags --refs https://github.com/openai/codex.git \
  | awk -F/ '/refs\/tags\/rust-v[0-9]+\.[0-9]+\.[0-9]+$/ {print $NF}' \
  | sed 's/^rust-v//' \
  | sort -V \
  | tail -n1)

if [[ -z "${latest_tag}" ]]; then
  echo "Error: Could not determine latest rust tag from GitHub." >&2
  exit 1
fi

echo "Latest rust tag: rust-v${latest_tag}"

if [[ "${latest_tag}" == "${currentVersion}" ]]; then
  echo "Already at latest version (${currentVersion}). Recomputing hashes only."
fi

declare -A asset_files=(
  ["x86_64-linux"]="codex-x86_64-unknown-linux-gnu.tar.gz"
  ["aarch64-linux"]="codex-aarch64-unknown-linux-gnu.tar.gz"
  ["x86_64-darwin"]="codex-x86_64-apple-darwin.tar.gz"
  ["aarch64-darwin"]="codex-aarch64-apple-darwin.tar.gz"
)

declare -A asset_hashes

for system in "${!asset_files[@]}"; do
  archive="${asset_files[$system]}"
  url="https://github.com/openai/codex/releases/download/rust-v${latest_tag}/${archive}"
  echo "Prefetching ${system} asset: ${url}"
  prefetch_output=$(nix-prefetch-url --type sha256 "$url")
  hash_base32=$(echo "$prefetch_output" | head -n1)
  hash_sri=$(nix hash convert --hash-algo sha256 --from nix32 --to sri "$hash_base32")
  echo "Computed ${system} sha256: ${hash_sri}"
  asset_hashes[$system]="$hash_sri"
done

echo "Updating ${PKG_FILE} with new version and hashes..."
systems=("x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin")

{
  cat <<EOF
{ lib
, stdenv
, stdenvNoCC
, fetchurl
, makeWrapper
, autoPatchelfHook ? null
, openssl
, prevCodex ? null
}:

let
  version = "${latest_tag}";
  system = stdenv.hostPlatform.system;
  assets = {
EOF

  for system in "${systems[@]}"; do
    archive="${asset_files[$system]}"
    sha="${asset_hashes[$system]}"
    binary="${archive%.tar.gz}"
    cat <<EOF
    "${system}" = {
      archive = "${archive}";
      sha256 = "${sha}";
      binary = "${binary}";
    };
EOF
  done

  cat <<'EOF'
  };
  asset = lib.attrByPath [ system ] null assets;
  linuxPatchelfInputs = lib.optionals (stdenv.isLinux && autoPatchelfHook != null) [ autoPatchelfHook ];
  linuxLibs = lib.optionals stdenv.isLinux [ stdenv.cc.cc.lib openssl ];
in
if asset == null then
  (if prevCodex == null then lib.throw "codex: unsupported platform ${system}" else prevCodex)
else
  stdenvNoCC.mkDerivation {
    pname = "codex";
    inherit version;

    src = fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/${asset.archive}";
      sha256 = asset.sha256;
    };

    dontBuild = true;
    sourceRoot = ".";

    nativeBuildInputs = [ makeWrapper ] ++ linuxPatchelfInputs;
    buildInputs = linuxLibs;

    installPhase = ''
      runHook preInstall
      install -Dm755 ${asset.binary} $out/bin/codex
      wrapProgram $out/bin/codex \
        --add-flags "--dangerously-bypass-approvals-and-sandbox"
      runHook postInstall
    '';

    meta = (if prevCodex != null then prevCodex.meta else { }) // {
      inherit version;
    };
  }
EOF
} > "$PKG_FILE"

echo "Reformatting Nix expression..."
nix fmt "$PKG_FILE"

echo "Update completed: rust-v${latest_tag}"
