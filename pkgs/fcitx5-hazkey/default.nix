{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, fcitx5
, qt6
, qt6Packages
, vulkan-loader
}:

let
  version = "0.2.1";

  src = fetchurl {
    url = "https://github.com/7ka-Hiira/hazkey/releases/download/${version}/fcitx5-hazkey-${version}-x86_64.tar.gz";
    hash = "sha256-/u2f0L0p8h/eK347VVRGkjWZN9dD9MMB3Fxuv6d39Vs=";
  };

  licenseFile = fetchurl {
    url = "https://raw.githubusercontent.com/7ka-Hiira/fcitx5-hazkey/refs/tags/${version}/LICENSE";
    hash = "sha256-Ef0epB37DYFSH5rHVDDXgd+t1AdkwI98FbQS4+lnuG0=";
  };
in
stdenv.mkDerivation {
  pname = "fcitx5-hazkey";
  inherit version src;

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    qt6Packages.wrapQtAppsHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    fcitx5
    qt6.qtbase
    qt6.qtwayland
    vulkan-loader
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
        runHook preInstall

        install -Dm755 usr/lib/x86_64-linux-gnu/hazkey/hazkey-server \
          $out/lib/hazkey/hazkey-server
        cp -r usr/lib/x86_64-linux-gnu/hazkey/libllama $out/lib/hazkey/

        install -Dm755 usr/lib/x86_64-linux-gnu/hazkey/hazkey-settings \
          $out/bin/hazkey-settings
        install -Dm644 usr/lib/x86_64-linux-gnu/fcitx5/fcitx5-hazkey.so \
          $out/lib/fcitx5/fcitx5-hazkey.so

        install -Dm644 usr/share/fcitx5/addon/hazkey.conf \
          $out/share/fcitx5/addon/hazkey.conf
        install -Dm644 usr/share/fcitx5/inputmethod/hazkey.conf \
          $out/share/fcitx5/inputmethod/hazkey.conf
        install -Dm644 usr/share/applications/hazkey-settings.desktop \
          $out/share/applications/hazkey-settings.desktop
        install -Dm644 usr/share/metainfo/org.fcitx.Fcitx5.Addon.Hazkey.metainfo.xml \
          $out/share/metainfo/org.fcitx.Fcitx5.Addon.Hazkey.metainfo.xml

        mkdir -p $out/share/hazkey
        cp -r usr/share/hazkey/. $out/share/hazkey/

        install -Dm644 ${licenseFile} $out/share/licenses/$pname/LICENSE

    {
      printf '%s\n' \
        '#!${stdenv.shell}' \
        'set -euo pipefail' \
        "" \
        'config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"' \
        'env_file="$config_home/hazkey/env"' \
        "" \
        'if [ -f "$env_file" ]; then' \
        '  . "$env_file"' \
        'fi' \
        "" \
        'export GGML_BACKEND_DIR="''${GGML_BACKEND_DIR:-@out@/lib/hazkey/libllama/backends}"' \
        'export HAZKEY_DICTIONARY="''${HAZKEY_DICTIONARY:-@out@/share/hazkey/Dictionary}"' \
        "" \
        'exec "@out@/lib/hazkey/hazkey-server" "$@"'
    } > $out/bin/hazkey-server
    substituteInPlace $out/bin/hazkey-server --replace-fail '@out@' "$out"
    chmod 755 $out/bin/hazkey-server

        runHook postInstall
  '';

  preFixup = ''
    addAutoPatchelfSearchPath $out/lib/hazkey/libllama
    addAutoPatchelfSearchPath $out/lib/hazkey/libllama/backends

    qtWrapperArgs+=(
      --set-default GGML_BACKEND_DIR "$out/lib/hazkey/libllama/backends"
      --set-default HAZKEY_DICTIONARY "$out/share/hazkey/Dictionary"
    )
  '';

  meta = {
    description = "Japanese input method for Fcitx5 powered by azooKey";
    homepage = "https://hazkey.hiira.dev/";
    license = lib.licenses.mit;
    mainProgram = "hazkey-settings";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
