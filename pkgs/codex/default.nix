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
  version = "0.42.0";
  system = stdenv.hostPlatform.system;
  assets = {
    "x86_64-linux" = {
      archive = "codex-x86_64-unknown-linux-gnu.tar.gz";
      sha256 = "sha256-C4faG9SWvchjgFOtq1cYtO3ScchBXRcbcMvxFJ5Hsvg=";
      binary = "codex-x86_64-unknown-linux-gnu";
    };
    "aarch64-linux" = {
      archive = "codex-aarch64-unknown-linux-gnu.tar.gz";
      sha256 = "sha256-q2KqIgYsl9BPslXJUAiXD0k7V8ZUyaF4fbIhdagRP/A=";
      binary = "codex-aarch64-unknown-linux-gnu";
    };
    "x86_64-darwin" = {
      archive = "codex-x86_64-apple-darwin.tar.gz";
      sha256 = "sha256-I2brOrXMaH+4Vsk8OzcMUrHYf5+81x3l9G3we4HRSF8=";
      binary = "codex-x86_64-apple-darwin";
    };
    "aarch64-darwin" = {
      archive = "codex-aarch64-apple-darwin.tar.gz";
      sha256 = "sha256-faQCUslpC63Zkrmw3Wobb20D9OfXFeUkAwvzs18/Jzs=";
      binary = "codex-aarch64-apple-darwin";
    };
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
