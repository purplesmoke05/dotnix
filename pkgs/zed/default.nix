{ lib
, stdenv
, fetchurl
, makeWrapper
, alsa-lib
, zed-editor
}:

if !stdenv.hostPlatform.isLinux then
  zed-editor
else
let
  version = "0.227.1";
  arch =
    if stdenv.hostPlatform.parsed.cpu.name == "x86_64" then
      "x86_64"
    else if stdenv.hostPlatform.parsed.cpu.name == "aarch64" then
      "aarch64"
    else
      throw "Unsupported architecture: ${stdenv.hostPlatform.parsed.cpu.name}";
  hashes = {
    x86_64 = "sha256-IHS6EUaTaMaZGbuQmD6ppRXG1H6fDQIm5JUGbjmxBSQ=";
    aarch64 = "sha256-VLV8m0BHwCLHDTzjb3KqRf74Pa66jLF8qCR2WFOh0xc=";
  };
  libPath = lib.makeLibraryPath [
    stdenv.cc.cc.lib
    alsa-lib
  ];
in
stdenv.mkDerivation {
  pname = "zed-editor";
  inherit version;

  src = fetchurl {
    url = "https://github.com/zed-industries/zed/releases/download/v${version}/zed-linux-${arch}.tar.gz";
    hash = hashes.${arch};
  };

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    tar -xzf "$src" --strip-components=1 -C "$out"

    wrapProgram "$out/bin/zed" \
      --prefix LD_LIBRARY_PATH : "${libPath}" \
      --set ZED_UPDATE_EXPLANATION "Zed has been installed using Nix. Auto-updates have thus been disabled."

    ln -s "$out/bin/zed" "$out/bin/zeditor"

    runHook postInstall
  '';

  meta = zed-editor.meta // {
    mainProgram = "zeditor";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ] ++ lib.optionals stdenv.hostPlatform.isDarwin zed-editor.meta.platforms;
  };
}
