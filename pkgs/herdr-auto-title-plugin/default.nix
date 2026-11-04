{ lib
, stdenvNoCC
, fetchFromGitHub
, fetchurl
}:

let
  version = "0.18.0";

  # Map Nix systems to Auto Title release assets. / Nix system を Auto Title の release asset に対応付ける。
  sources = {
    x86_64-linux = {
      asset = "herdr-auto-title-linux-amd64";
      hash = "sha256-vqt89lfJFRr08rtjpDC9AMAQqwzF73is1HmHGuVDdxE=";
    };
    aarch64-linux = {
      asset = "herdr-auto-title-linux-arm64";
      hash = "sha256-4XKbhtohVvXvA4E3GdfeD8krqbF93AXnFbS30m+u+kA=";
    };
    x86_64-darwin = {
      asset = "herdr-auto-title-macos-amd64";
      hash = "sha256-SDPsL5ZjagrQ+2fRc6Dz0GpWEbv+6e6/FVuaIdpUEdU=";
    };
    aarch64-darwin = {
      asset = "herdr-auto-title-macos-arm64";
      hash = "sha256-jp6+XqBDlYh949xZTVYeBAxL1uoUIvTlz2ABmUJ0DYQ=";
    };
  };

  srcConfig = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-auto-title-plugin";
  inherit version;

  src = fetchFromGitHub {
    owner = "kryptamine";
    repo = "herdr-auto-title";
    rev = "v${finalAttrs.version}";
    hash = "sha256-HhzsksVi8e5hT45ZI8SfoqeYXZ8PSchV/XE4MTVDUfk=";
  };

  binary = fetchurl {
    url = "https://github.com/kryptamine/herdr-auto-title/releases/download/v${finalAttrs.version}/${srcConfig.asset}";
    inherit (srcConfig) hash;
  };

  # Ship the release binary instead of the install-time Go build. / install 時の Go build の代わりに release binary を同梱する。
  postPatch = ''
    substituteInPlace herdr-plugin.toml \
      --replace-fail $'[[build]]\nplatforms = ["linux", "macos"]\ncommand = ["go", "build", "-o", "herdr-auto-title", "./cmd/herdr-auto-title"]\n\n' "" \
      --replace-fail $'[[build]]\nplatforms = ["windows"]\ncommand = ["go", "build", "-o", "herdr-auto-title.exe", "./cmd/herdr-auto-title"]\n\n' ""
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R . "$out/"
    # The manifest starts ./herdr-auto-title from the plugin root. / manifest は plugin root の ./herdr-auto-title を起動する。
    install -Dm755 "$binary" "$out/herdr-auto-title"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -f "$out/herdr-plugin.toml"
    if grep -F '[[build]]' "$out/herdr-plugin.toml" >/dev/null; then
      echo "herdr-plugin.toml still contains a build hook" >&2
      exit 1
    fi
    "$out/herdr-auto-title" --version | grep -F ${finalAttrs.version} >/dev/null
    runHook postInstallCheck
  '';

  passthru.pluginId = "herdr.auto-title";

  meta = {
    description = "Herdr plugin that names tabs and panes from their working context";
    homepage = "https://github.com/kryptamine/herdr-auto-title";
    changelog = "https://github.com/kryptamine/herdr-auto-title/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "herdr-auto-title";
    platforms = lib.attrNames sources;
  };
})
