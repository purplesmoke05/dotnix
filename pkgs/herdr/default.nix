{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, writableTmpDirAsHomeHook
}:

let
  version = "0.8.2";

  # Map Nix systems to release manifest assets. / Nix system を release manifest の asset に対応付ける。
  sources = {
    x86_64-linux = {
      asset = "herdr-linux-x86_64";
      hash = "sha256-l2FQoU1JDJSyQ+ouGn6y37Z/EuNrGC25CTb2co5q7PQ=";
    };
    aarch64-linux = {
      asset = "herdr-linux-aarch64";
      hash = "sha256-9VYQZY4cLg0qrvcwtLKriF9/i6AChas3K/sU8uPVtA0=";
    };
    x86_64-darwin = {
      asset = "herdr-macos-x86_64";
      hash = "sha256-q1AmLIGQzXqpBW0knSVcCMMow+hxbenPop208TG44sE=";
    };
    aarch64-darwin = {
      asset = "herdr-macos-aarch64";
      hash = "sha256-pdT01QTYswnJH4EQUFWTAPq6MSWEJfU8UIUvyW9q5XQ=";
    };
  };

  srcConfig = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "herdr";
  inherit version;

  src = fetchurl {
    url = "https://github.com/ogulcancelik/herdr/releases/download/v${finalAttrs.version}/${srcConfig.asset}";
    inherit (srcConfig) hash;
  };

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/herdr
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ writableTmpDirAsHomeHook ];
  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR" "$out/bin/herdr" --version >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Terminal-native AI agent multiplexer (one terminal for the whole herd)";
    homepage = "https://herdr.dev";
    changelog = "https://github.com/ogulcancelik/herdr/releases/tag/v${finalAttrs.version}";
    # Dual-licensed AGPL-3.0-or-later / commercial. / デュアルライセンス。
    license = lib.licenses.agpl3Plus;
    mainProgram = "herdr";
    platforms = lib.attrNames sources;
  };
})
