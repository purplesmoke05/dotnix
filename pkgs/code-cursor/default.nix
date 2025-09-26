{ lib, stdenv, fetchurl, appimageTools, undmg, rsync, writeShellScriptBin, libsecret, xorg, gtk3, substituteInPlace }:

let
  pname = "cursor";
  version = "1.6.45";

  sources = {
    x86_64-linux = fetchurl {
      url = "https://downloads.cursor.com/production/3ccce8f55d8cca49f6d28b491a844c699b8719a3/linux/x64/Cursor-1.6.45-x86_64.AppImage";
      hash = "sha256-MlrevU26gD6hpZbqbdKQwnzJbm5y9SVSb3d0BGnHtpc=";
    };
    aarch64-linux = fetchurl {
      url = "https://downloads.cursor.com/production/3ccce8f55d8cca49f6d28b491a844c699b8719a3/linux/arm64/Cursor-1.6.45-aarch64.AppImage";
      hash = "sha256-eFHYRwVXhWB3zCnJFYodIxjR2ewP8ETgwyjBdB86oTk=";
    };
    x86_64-darwin = fetchurl {
      url = "https://downloads.cursor.com/production/3ccce8f55d8cca49f6d28b491a844c699b8719a3/darwin/x64/Cursor-darwin-x64.dmg";
      hash = "sha256-UGmMX9Wr69i2EqQSLkj9/ROs8HpLtc/x0IYDJdzvD6U=";
    };
    aarch64-darwin = fetchurl {
      url = "https://downloads.cursor.com/production/3ccce8f55d8cca49f6d28b491a844c699b8719a3/darwin/arm64/Cursor-darwin-arm64.dmg";
      hash = "sha256-lcuJiAgHXPEUZHNeanBq10znXKFKJ6yrluuZjdaQbyA=";
    };
  };

  src = sources.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };

  linux = appimageTools.wrapType2 {
    inherit pname version src;

    extraPkgs = pkgs: with pkgs; [
      libsecret
      xorg.libxshmfence
      nss # nss is implicitly provided by stdenv on Linux, but good to be explicit if needed by the app
      xorg.libxkbfile
      xorg.libX11
      xorg.libXrandr
      xorg.libXi
      gtk3
      rsync # rsync is used in extraInstallCommands
    ];

    extraInstallCommands = ''
      ${rsync}/bin/rsync -a ${appimageContents}/usr/share $out/ --exclude "*.so"

      substituteInPlace $out/share/applications/cursor.desktop \
        --replace "/usr/share/cursor/cursor" "$out/bin/cursor" \
        --replace "Exec=cursor" "Exec=$out/bin/cursor"

      mv $out/bin/${pname} $out/bin/${pname}.bin
      cat > $out/bin/${pname} <<EOF
      #!/bin/sh
      # exec $out/bin/${pname}.bin --ozone-platform=x11 --enable-wayland-ime=true --disable-gpu --no-update "$@"
      exec $out/bin/${pname}.bin --enable-wayland-ime=true --no-update "$@"
      EOF
      chmod +x $out/bin/${pname}
    '';

    meta = with lib; {
      description = "The AI-first Code Editor";
      homepage = "https://cursor.sh/";
      license = licenses.unfree; # Assuming it's unfree, adjust if necessary
      maintainers = with maintainers; [ ]; # Add your maintainer name
      platforms = [ "x86_64-linux" "aarch64-linux" ];
      mainProgram = "cursor";
    };
  };

  darwin = stdenv.mkDerivation rec {
    inherit pname version src;

    nativeBuildInputs = [ undmg ];

    sourceRoot = "."; # DMG contains Cursor.app at the root

    installPhase = ''
      mkdir -p $out/Applications
      cp -r Cursor.app $out/Applications/
      mkdir -p $out/bin
      ln -s "$out/Applications/Cursor.app/Contents/Resources/app/bin/cursor" "$out/bin/cursor"
    '';

    meta = with lib; {
      description = "The AI-first Code Editor";
      homepage = "https://cursor.sh/";
      license = licenses.unfree; # Assuming it's unfree, adjust if necessary
      maintainers = with maintainers; [ ]; # Add your maintainer name
      platforms = [ "x86_64-darwin" "aarch64-darwin" ];
      mainProgram = "cursor";
    };
  };

in
if stdenv.isLinux then linux
else if stdenv.isDarwin then darwin
else throw "Unsupported platform for ${pname}"
