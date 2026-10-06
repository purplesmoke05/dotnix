{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, writableTmpDirAsHomeHook
}:

let
  version = "0.9.3";

  # Map Nix systems to release manifest assets. / Nix system を release manifest の asset に対応付ける。
  sources = {
    x86_64-linux = {
      asset = "herdr-linux-x86_64";
      hash = "sha256-GKjcZfHC+khYhDRDVt6hz9kRxvBs9G+njhk/QIf026c=";
    };
    aarch64-linux = {
      asset = "herdr-linux-aarch64";
      hash = "sha256-TeeqPiVniBLpKWDeZPfCqqG8ofD4CjxeVZg34jHh9cA=";
    };
    x86_64-darwin = {
      asset = "herdr-macos-x86_64";
      hash = "sha256-22LVSP8+gysIepaxiUoI0mvjkF8YMDCc1VZ4PyFdQFQ=";
    };
    aarch64-darwin = {
      asset = "herdr-macos-aarch64";
      hash = "sha256-UXOj4K5C1dGrfr+l1eYyn3w9I/jho2d8fOMjHaKIQVc=";
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
