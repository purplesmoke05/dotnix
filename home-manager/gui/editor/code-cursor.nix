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
    version = "0.48.6";

    sources = {
      x86_64-linux = fetchurl {
        url = "https://downloads.cursor.com/production/1649e229afdef8fd1d18ea173f063563f1e722ef/linux/x64/Cursor-0.48.6-x86_64.AppImage";
        hash = "sha256-ZiQpVRZRaFOJ8UbANRd1F+4uhv7W/t15d9wmGKshu80=";
      };
      aarch64-linux = fetchurl {
        url = "https://downloads.cursor.com/production/1649e229afdef8fd1d18ea173f063563f1e722ef/linux/arm64/Cursor-0.48.6-arm64.AppImage";
        hash = "sha256-JxCszBB3x+94ypHRDRm5IUbfbJzHdlA4FEtS9/AkGpM=";
      };
      x86_64-darwin = fetchurl {
        url = "https://downloads.cursor.com/production/1649e229afdef8fd1d18ea173f063563f1e722ef/mac/x64/Cursor-0.48.6-universal.dmg";
        hash = "sha256-JKWV/KP2Q0PwXJwIAqRsjsIYKzwwV7zQeS/RQOC2TQU=";
      };
      aarch64-darwin = fetchurl {
        url = "https://downloads.cursor.com/production/1649e229afdef8fd1d18ea173f063563f1e722ef/mac/arm64/Cursor-0.48.6-universal.dmg";
        hash = "sha256-JKWV/KP2Q0PwXJwIAqRsjsIYKzwwV7zQeS/RQOC2TQU=";
      };
    };

    src = sources.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

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
      ];

      extraInstallCommands = ''
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
      '';
    };
  in
    if stdenv.isLinux then linux
    else if stdenv.isDarwin then darwin
    else throw "Unsupported platform";

in {
  home.packages = with pkgs; [
    code-cursor-latest
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
