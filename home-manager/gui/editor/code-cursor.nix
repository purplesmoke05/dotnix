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

  # Renamed to avoid conflict with pkgs.code-cursor if it exists
  code-cursor-pkg = with pkgs; let
    # Updated version
    pname = "cursor";
    version = "0.48.9";
    inherit (stdenvNoCC) hostPlatform;

    # Updated sources based on nixpkgs definition for 0.48.9
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

    source = sources.${hostPlatform.system} or (throw "Unsupported system: ${hostPlatform.system}");

    # Helper definitions from nixpkgs package
    appimageContents = appimageTools.extractType2 {
      inherit pname version;
      src = source;
    };

    wrappedAppimage = appimageTools.wrapType2 {
      inherit pname version;
      src = source;
      # Note: extraPkgs are not directly used here, dependencies managed below
    };

  in
  stdenvNoCC.mkDerivation {
    inherit pname version;
    src = if hostPlatform.isLinux then wrappedAppimage else source;

    # Updated dependencies and build inputs based on nixpkgs
    nativeBuildInputs =
      lib.optionals hostPlatform.isLinux [
        autoPatchelfHook
        glibcLocales # Ensure locales are available
        makeWrapper
        rsync
      ]
      ++ lib.optionals hostPlatform.isDarwin [ undmg ];

    buildInputs = lib.optionals hostPlatform.isLinux [
      alsa-lib
      at-spi2-atk
      cairo
      cups
      curlWithGnuTls # Or specify curl variant if needed
      egl-wayland
      expat
      # Use vivaldi-ffmpeg-codecs in buildInputs as per nixpkgs derivation
      vivaldi-ffmpeg-codecs
      glib
      gtk3
      libdrm
      libgbm
      libGL
      libva-minimal # or libva
      libxkbcommon
      xorg.libxkbfile
      nspr
      nss
      pango
      pulseaudio
      # vivaldi-ffmpeg-codecs # Use this if standard ffmpeg doesn't work
      vulkan-loader
      wayland
    ];

    # Runtime dependencies based on nixpkgs
    runtimeDependencies = lib.optionals hostPlatform.isLinux [
      egl-wayland
      ffmpeg # Or vivaldi-ffmpeg-codecs if needed
      glibc
      libappindicator-gtk3
      libnotify
      xorg.libxkbfile
      pciutils
      pulseaudio
      wayland
      fontconfig
      freetype
      # Added libsecret based on previous derivation
      libsecret
      # Added missing X11 libs based on previous derivation, though Wayland is preferred
      xorg.libX11
      xorg.libXrandr
      xorg.libXi
      xorg.libxshmfence
    ];

    # Patchelf settings for Linux - Hook is added to nativeBuildInputs
    # Configuration is passed via environment variables below if needed.
    # autoPatchelfHook = lib.optionalAttrs hostPlatform.isLinux {
    #   # Add libraries needed at runtime but not auto-detected
    #   extraRuntimeDependencies = builtins.attrValues (runtimeDependencies);
    #   # Ensure correct interpreter is used
    #   interpreterNames = [ "ld-linux-*.so.*" ];
    # };

    # Correct sourceRoot for Darwin builds
    sourceRoot = lib.optionalString hostPlatform.isDarwin ".";

    # Prevent modifications that break signing on Darwin
    dontUpdateAutotoolsGnuConfigScripts = hostPlatform.isDarwin;
    dontConfigure = hostPlatform.isDarwin;
    dontFixup = hostPlatform.isDarwin; # Let the installPhase handle linking

    installPhase = ''
      runHook preInstall

      mkdir -p $out/

      ${lib.optionalString hostPlatform.isLinux ''
        # Configure autoPatchelfHook if needed (interpreter name)
        export autoPatchelfHookInterpreterNames="ld-linux-*.so.*"

        # Copy binaries
        cp -r bin $out/bin

        # Copy shared resources using rsync as in nixpkgs
        rsync -a -q ${appimageContents}/usr/share $out/ --exclude "*.so"

        # Fix desktop file path
        substituteInPlace $out/share/applications/cursor.desktop \
          --replace-fail "/usr/share/cursor/cursor" "$out/bin/cursor" \
          --replace "Exec=cursor" "Exec=$out/bin/cursor"

        # Wrap the executable using makeWrapper (nixpkgs style)
        # Add --no-update flag and Wayland flags conditionally
        wrapProgram $out/bin/cursor \
          --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
          --add-flags "--no-update" # Prevent in-app updates
          # Add previous --disable-gpu flag if needed: --add-flags "--disable-gpu"
      ''}

      ${lib.optionalString hostPlatform.isDarwin ''
        APP_DIR="$out/Applications"
        mkdir -p "$APP_DIR"
        cp -Rp Cursor.app "$APP_DIR"
        mkdir -p "$out/bin"
        # Ensure the symlink target exists and points correctly
        ln -s "$APP_DIR/Cursor.app/Contents/Resources/app/bin/cursor" "$out/bin/cursor"
      ''}

      runHook postInstall
    '';

    passthru = {
      # Keep the original passthru if needed, e.g., for update scripts
      inherit sources;
      # updateScript = ./update.sh; # Keep if you have an update script
    };

    # Meta information based on nixpkgs
    meta = {
      description = "AI-powered code editor built on vscode";
      homepage = "https://cursor.com";
      changelog = "https://cursor.com/changelog";
      license = lib.licenses.unfree; # Marked as unfree in nixpkgs
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      maintainers = with lib.maintainers; [ ]; # Add your maintainer name here if desired
      platforms = lib.platforms.linux ++ lib.platforms.darwin;
      mainProgram = "cursor";
    };
  };

in
{
  # Use the updated package definition
  home.packages = [ code-cursor-pkg ];

  # Keep the activation script for settings/keybindings
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
