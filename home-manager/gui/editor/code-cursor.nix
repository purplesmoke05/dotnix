{ pkgs, config, lib, ... }:
let
  beautifyJson = json:
    pkgs.runCommand "beautified.json"
      {
        buildInputs = [ pkgs.jq ];
        passAsFile = [ "jsonContent" ];
        jsonContent = json;
      } ''
      cat $jsonContentPath | jq '.' > $out
    '';

  code-cursor-latest = with pkgs; let
    pname = "cursor";
    version = "0.48.9";

    sources = {
      x86_64-linux = fetchurl {
        url = "https://downloads.cursor.com/production/61e99179e4080fecf9d8b92c6e2e3e00fbfb53f4/linux/x64/Cursor-0.48.9-x86_64.AppImage";
        hash = "sha256-Rw96CIN+vL1bIj5o68gWkHeiqgxExzbjwcW4ad10M2I=";
      };
      aarch64-linux = fetchurl {
        url = "https://downloads.cursor.com/production/61e99179e4080fecf9d8b92c6e2e3e00fbfb53f4/linux/arm64/Cursor-0.48.9-aarch64.AppImage";
        hash = "sha256-RMDYoQSIO0jukhC5j1TjpwCcK0tEnvoVpXbFOxp/K8o=";
      };
      x86_64-darwin = fetchurl {
        url = "https://downloads.cursor.com/production/61e99179e4080fecf9d8b92c6e2e3e00fbfb53f4/darwin/x64/Cursor-darwin-x64.dmg";
        hash = "sha256-172BGNNVvpZhk99rQN19tTsxvRADjmtEzgkZazke/v4=";
      };
      aarch64-darwin = fetchurl {
        url = "https://downloads.cursor.com/production/61e99179e4080fecf9d8b92c6e2e3e00fbfb53f4/darwin/arm64/Cursor-darwin-arm64.dmg";
        hash = "sha256-IQ4UZwEBVGMaGUrNVHWxSRjbw8qhLjOJ2KYc9Y26LZU=";
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
        exec $out/bin/${pname}.bin --ozone-platform-hint=auto --enable-wayland-ime=true --disable-gpu --no-update "$@"
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

in
{
  home.packages = with pkgs; [
    code-cursor-latest
  ];

  home.activation = {
    writeCursorConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p ${config.home.homeDirectory}/.config/Cursor/User
      $DRY_RUN_CMD cp ${beautifyJson (builtins.toJSON (import ./vscode/settings.nix))} ${config.home.homeDirectory}/.config/Cursor/User/settings.json
      $DRY_RUN_CMD cp ${beautifyJson (builtins.toJSON (import ./vscode/keybindings.nix))} ${config.home.homeDirectory}/.config/Cursor/User/keybindings.json
      $DRY_RUN_CMD chmod 644 ${config.home.homeDirectory}/.config/Cursor/User/settings.json
      $DRY_RUN_CMD chmod 644 ${config.home.homeDirectory}/.config/Cursor/User/keybindings.json
    '';
  };
}
