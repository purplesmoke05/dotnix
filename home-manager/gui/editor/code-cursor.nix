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
    version = "0.49.6";

    sources = {
      x86_64-linux = fetchurl {
        url = "https://downloads.cursor.com/production/0781e811de386a0c5bcb07ceb259df8ff8246a52/linux/x64/Cursor-0.49.6-x86_64.AppImage";
        hash = "sha256-WH4/Zw0VJmRGyRzMlkThkhZ4fGysMKBUSIPCTsyGS4w=";
      };
      aarch64-linux = fetchurl {
        url = "https://downloads.cursor.com/production/0781e811de386a0c5bcb07ceb259df8ff8246a52/linux/arm64/Cursor-0.49.6-aarch64.AppImage";
        hash = "sha256-cpNoff6mDRkT2RicaDlxzqVP9BNe6UEGgJVHr1xMiv0=";
      };
      x86_64-darwin = fetchurl {
        url = "https://downloads.cursor.com/production/0781e811de386a0c5bcb07ceb259df8ff8246a52/darwin/x64/Cursor-darwin-x64.dmg";
        hash = "sha256-fAaLY9YTIuNThFl5OsIMHavy2xwDgYooL4xTSp4Cwzw=";
      };
      aarch64-darwin = fetchurl {
        url = "https://downloads.cursor.com/production/0781e811de386a0c5bcb07ceb259df8ff8246a52/darwin/arm64/Cursor-darwin-arm64.dmg";
        hash = "sha256-DNN2+gfs9u0tZmh75J258d2TL6ErIYludMgPJZcgfb8=";
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
