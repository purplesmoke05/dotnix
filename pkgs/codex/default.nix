{ lib
, stdenv
, fetchurl
, autoPatchelfHook ? null
, makeWrapper
, openssl ? null
, zlib ? null
}:

let
  version = "0.77.0";

  platforms = {
    x86_64-linux = {
      artifact = "codex-x86_64-unknown-linux-gnu.tar.gz";
      sha256 = "sha256-VNHfvM2WJRKORMZfgGQCFTFJKf0sX1Lv0fI2mO0nOIs=";
      nativeBuildInputs = lib.filter (x: x != null) [ autoPatchelfHook makeWrapper ];
      buildInputs = lib.filter (x: x != null) [ stdenv.cc.cc.lib openssl zlib ];
    };

    aarch64-linux = {
      artifact = "codex-aarch64-unknown-linux-gnu.tar.gz";
      sha256 = "sha256-GTvg6v591jykOSdtw4U1r62c6Gka+FW9lty4GWBZIWo=";
      nativeBuildInputs = lib.filter (x: x != null) [ autoPatchelfHook makeWrapper ];
      buildInputs = lib.filter (x: x != null) [ stdenv.cc.cc.lib openssl zlib ];
    };

    x86_64-darwin = {
      artifact = "codex-x86_64-apple-darwin.tar.gz";
      sha256 = "sha256-WBghVGaaj17PQ+y4l7JBTKp5vI25b4Ov9N9gsQh1MuI=";
      nativeBuildInputs = [ makeWrapper ];
    };

    aarch64-darwin = {
      artifact = "codex-aarch64-apple-darwin.tar.gz";
      sha256 = "sha256-O0XcRH5Sht2VmtBQ6cPxaqiLvTxpQ++8ldqnwdI5PRA=";
      nativeBuildInputs = [ makeWrapper ];
    };
  };

  config = platforms.${stdenv.system} or null;

  throwForSystem = throw "No prebuilt Codex binary for ${stdenv.system}.";

  codexUrl = system: artifact:
    "https://github.com/openai/codex/releases/download/rust-v${version}/${artifact}";
in
if config == null then
  throwForSystem
else
  let
    binaryName = lib.removeSuffix ".tar.gz" config.artifact;
  in
  stdenv.mkDerivation rec {
    pname = "codex";
    inherit version;

    src = fetchurl {
      url = codexUrl stdenv.system config.artifact;
      sha256 = config.sha256;
    };

    nativeBuildInputs = config.nativeBuildInputs;
    buildInputs = config.buildInputs or [ ];

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack
      tar -xzf "$src"
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 "${binaryName}" "$out/bin/codex"
      runHook postInstall
    '';

    postInstall = ''
      if [ -x "$out/bin/codex" ]; then
        mv "$out/bin/codex" "$out/bin/.codex-real"
        cat > "$out/bin/codex" <<'EOF'
#!${stdenv.shell}
set -eo pipefail

binary="@codex_real@"

if [ -n "$CODEX_SKIP_DEFAULT_DANGEROUS" ] && [ "$CODEX_SKIP_DEFAULT_DANGEROUS" != "0" ]; then
  exec -a "$0" "$binary" "$@"
fi

need_flag=1
prev=""
for arg in "$@"; do
  case "$prev" in
    -s|--sandbox|-a|--ask-for-approval)
      need_flag=0
      break
      ;;
  esac

  case "$arg" in
    --dangerously-bypass-approvals-and-sandbox|--full-auto|-s|-s=*|--sandbox|--sandbox=*|-a|-a=*|--ask-for-approval|--ask-for-approval=*)
      need_flag=0
      break
      ;;
  esac

  prev="$arg"
done

if [ "$need_flag" -eq 1 ]; then
  set -- --dangerously-bypass-approvals-and-sandbox "$@"
fi

exec -a "$0" "$binary" "$@"
EOF
        substituteInPlace "$out/bin/codex" --replace "@codex_real@" "$out/bin/.codex-real"
        chmod 755 "$out/bin/codex"
      fi
    '';

    meta = {
      description = "Command line interface for OpenAI Codex";
      longDescription = "Prebuilt Codex CLI with sandbox override wrapper.";
      homepage = "https://github.com/openai/codex";
      license = lib.licenses.asl20;
      maintainers = with lib.maintainers; [ ];
      platforms = lib.attrNames platforms;
    };
  }
