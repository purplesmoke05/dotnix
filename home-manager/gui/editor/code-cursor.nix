{pkgs, config, lib, ...}: let
  beautifyJson = json:
    pkgs.runCommand "beautified.json" {
      buildInputs = [ pkgs.jq ];
      passAsFile = [ "jsonContent" ];
      jsonContent = json;
    } ''
      cat $jsonContentPath | jq '.' > $out
    '';

  code-cursor-latest
  = with pkgs; let
    pname = "cursor";
    version = "0.48.7";

    sources = {
      x86_64-linux = fetchurl {
        url = "https://downloads.cursor.com/production/1d623c4cc1d3bb6e0fe4f1d5434b47b958b05876/linux/x64/Cursor-0.48.7-x86_64.AppImage";
        hash = "sha256-LxAUhmEM02qCaeUUsHgjv0upAF7eerX+/QiGeKzRY4M=";
      };
      aarch64-linux = fetchurl {
        url = "https://downloads.cursor.com/production/1d623c4cc1d3bb6e0fe4f1d5434b47b958b05876/linux/arm64/Cursor-0.48.7-aarch64.AppImage";
        hash = "sha256-l1T0jLX7oWjq4KzxO4QniUAjzVbBu4SWA1r5aXGpDS4=";
      };
      x86_64-darwin = fetchurl {
        url = "https://downloads.cursor.com/production/1d623c4cc1d3bb6e0fe4f1d5434b47b958b05876/darwin/x64/Cursor-darwin-x64.dmg";
        hash = "sha256-h9zcmZRpOcfBRK5Xw/AdY/rwlINEHYiUgpCoGXg6hSY=";
      };
      aarch64-darwin = fetchurl {
        url = "https://downloads.cursor.com/production/1d623c4cc1d3bb6e0fe4f1d5434b47b958b05876/darwin/arm64/Cursor-darwin-arm64.dmg";
        hash = "sha256-FsXabTXN1Bkn1g4ZkQVqa+sOx4JkSG9c09tp8lAcPKM=";
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
        nss
        xorg.libxkbfile
        xorg.libX11
        xorg.libXrandr
        xorg.libXi
        gtk3
        rsync
      ];

      extraInstallCommands = ''
        ${pkgs.rsync}/bin/rsync -a ${appimageContents}/usr/share $out/ --exclude "*.so"

        substituteInPlace $out/share/applications/cursor.desktop \
          --replace "/usr/share/cursor/cursor" "$out/bin/cursor" \
          --replace "Exec=cursor" "Exec=$out/bin/cursor"

        mv $out/bin/${pname} $out/bin/${pname}.bin
        cat > $out/bin/${pname} <<EOF
        #!/bin/sh
        exec $out/bin/${pname}.bin --ozone-platform-hint=auto --enable-wayland-ime=true --disable-gpu "\$@"
        EOF
        chmod +x $out/bin/${pname}
      '';
    };

    darwin = stdenvNoCC.mkDerivation {
      inherit pname version src;

      nativeBuildInputs = [ undmg ];

      sourceRoot = ".";

      installPhase = ''
        mkdir -p $out/Applications
        cp -r Cursor.app $out/Applications/
        mkdir -p $out/bin
        ln -s "$out/Applications/Cursor.app/Contents/Resources/app/bin/cursor" "$out/bin/cursor"
      '';
    };
  in
    if stdenv.isLinux then linux
    else if stdenv.isDarwin then darwin
    else throw "Unsupported platform";

in {
  home.packages = with pkgs; [
    code-cursor
  ];

  home.activation = {
    writeCursorConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD mkdir -p ${config.home.homeDirectory}/.config/Cursor/User
      $DRY_RUN_CMD cp ${beautifyJson (builtins.toJSON (import ./vscode/settings.nix))} ${config.home.homeDirectory}/.config/Cursor/User/settings.json
      $DRY_RUN_CMD cp ${beautifyJson (builtins.toJSON (import ./vscode/keybindings.nix))} ${config.home.homeDirectory}/.config/Cursor/User/keybindings.json
      $DRY_RUN_CMD chmod 644 ${config.home.homeDirectory}/.config/Cursor/User/settings.json
      $DRY_RUN_CMD chmod 644 ${config.home.homeDirectory}/.config/Cursor/User/keybindings.json
    '';
  };
}
