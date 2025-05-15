{ lib, stdenv, fetchurl, appimageTools, undmg, rsync, writeShellScriptBin, libsecret, xorg, gtk3, substituteInPlace }:

let
  pname = "cursor";
  version = "0.50.4";

  sources = {
    x86_64-linux = fetchurl {
      url = "https://downloads.cursor.com/production/8ea935e79a50a02da912a034bbeda84a6d3d355d/linux/x64/Cursor-0.50.4-x86_64.AppImage";
      hash = "sha256-ik+2TqmRhnzXM+qoCQ+KLQkW/cqZSqcZS2P2yuUPGI8=";
    };
    aarch64-linux = fetchurl {
      url = "https://downloads.cursor.com/production/8ea935e79a50a02da912a034bbeda84a6d3d355d/linux/arm64/Cursor-0.50.4-aarch64.AppImage";
      hash = "sha256-k8/LdL/HmpwwyMFuuA6Q7RzsbQM5gpyraDHHI0myyoE=";
    };
    x86_64-darwin = fetchurl {
      url = "https://downloads.cursor.com/production/8ea935e79a50a02da912a034bbeda84a6d3d355d/darwin/x64/Cursor-darwin-x64.dmg";
      hash = "sha256-fzeHVa0ojHE53RPqHjP7aCcNkfJuMs3xeq6JjBP2A5k=";
    };
    aarch64-darwin = fetchurl {
      url = "https://downloads.cursor.com/production/8ea935e79a50a02da912a034bbeda84a6d3d355d/darwin/arm64/Cursor-darwin-arm64.dmg";
      hash = "sha256-qCwolJTdqFUDGrZBOcnAkdLPBGZ0FUzR4HovDKGU7Lk=";
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
      exec $out/bin/${pname}.bin --ozone-platform-hint=auto --enable-wayland-ime=true --disable-gpu --no-update "$@"
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