{ lib
, python3Packages
, fetchFromGitHub
, wrapGAppsHook3
, makeWrapper
, gobject-introspection
, at-spi2-core
, glib
, gtk3
, pango
, gdk-pixbuf
, harfbuzz
, cairo
, gtk-layer-shell
}:

python3Packages.buildPythonApplication rec {
  pname = "hints";
  # Pin a commit or release tag and update the version accordingly.
  # Version will be refined once the revision is pinned.
  version = "unstable";

  src = fetchFromGitHub {
    owner = "AlfredoSequeida";
    repo = "hints";
    # Pinned upstream commit
    rev = "ae3112c724b3a9f3be7e4b59d5203ebcf070bf69";
    # Fixed-output hash for the pinned commit
    sha256 = "sha256-Z+KCTi0nZL9+InpaL2dfwV7YYdP9R0rLtGySQ0MysEU=";
  };

  patches = [
    ./no-gtk-animations.patch
  ];

  # (We patch upstream file in postPatch below to improve Wayland/Hyprland auto-detection)

  # Build using PEP 517 (pyproject.toml) if present; this is compatible with both
  # setuptools and poetry projects
  format = "pyproject";
  nativeBuildInputs = [ wrapGAppsHook3 ]
    ++ (with python3Packages; [
      setuptools
      wheel
      poetry-core
    ]);

  buildInputs = [
    at-spi2-core
    gobject-introspection
    glib
    gtk3
    pango
    gdk-pixbuf
    harfbuzz
    cairo
    gtk-layer-shell
  ];

  # No extra postInstall wrapper; gappsWrapperArgs is sufficient. / postInstall の追加ラップは不要（gappsWrapperArgs で十分）

  # Ensure wrapGAppsHook3 includes all required GI typelib and data dirs
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix GI_TYPELIB_PATH : "${lib.getLib gtk3}/lib/girepository-1.0:${lib.getLib pango}/lib/girepository-1.0:${lib.getLib gdk-pixbuf}/lib/girepository-1.0:${lib.getLib at-spi2-core}/lib/girepository-1.0:${lib.getLib harfbuzz}/lib/girepository-1.0:${lib.getLib gtk-layer-shell}/lib/girepository-1.0:${lib.getLib glib}/lib/girepository-1.0:${lib.getLib gobject-introspection}/lib/girepository-1.0"
      --prefix XDG_DATA_DIRS : "${gtk3}/share:${gdk-pixbuf}/share:${glib}/share"
    )
  '';

  # Remove the post-install hook that writes into home/systemd (side effects disallowed). / ホームや systemd に書き込む post-install フックを削除（副作用は不可）
  # Disabled because Nix builds must stay side-effect free. / Nix ビルドでは副作用が許されないため無効化。
  postPatch = ''
    substituteInPlace setup.py \
      --replace 'cmdclass={"install": PostInstallCommand},' ""

    # Add lowercase hyprland to Wayland detection candidates. / Wayland 自動判定の候補に小文字 hyprland を追加。
    substituteInPlace hints/hints.py \
      --replace 'supported_wayland_wms = {"sway", "Hyprland", "plasmashell"}' 'supported_wayland_wms = {"sway", "Hyprland", "hyprland", "plasmashell"}'

    # Relax pygobject version requirement
    # Aggressively find and replace in all files with flexible regex
    grep -rl "pygobject" . | xargs sed -i 's/pygobject.*[=<>].*/pygobject>=3.50.0/g' || true

    # Allow forcing the window system via HINTS_WINDOW_SYSTEM env var. / HINTS_WINDOW_SYSTEM 環境変数でウィンドウシステムを強制。
    sed -i '0,/if not window_system_id:/{s//env_choice = __import__("os").getenv("HINTS_WINDOW_SYSTEM", "")\n    if env_choice:\n        window_system_id = env_choice\n    if not window_system_id:/}' hints/hints.py

    # Add Hyprland environment fallback when detection fails. / 検出失敗時に Hyprland 用フォールバックを追加。
    sed -i '/^\s*window_system = get_window_system_class(window_system_id)$/i \
        if not window_system_id:\n\
            import os\n\
            env = (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or os.getenv("XDG_CURRENT_DESKTOP") or os.getenv("XDG_SESSION_DESKTOP") or os.getenv("DESKTOP_SESSION") or "")\n\
            if "hyprland" in env.lower():\n\
                window_system_id = "hyprland"\n' hints/hints.py
  '';

  # The upstream build process tries to set up a background service (hintsd)
  # and expects to know the binary install directory. Point it to $out/bin
  # so the build doesn't fail during wheel installation.
  preBuild = ''
    export HINTS_EXPECTED_BIN_DIR="$out/bin"
    export HOME="$TMPDIR"
    export XDG_CONFIG_HOME="$TMPDIR/.config"
  '';

  # No extra postFixup; rely on gapps wrapping. / 追加の postFixup は不要（gapps ラップに統一）。

  # Runtime dependencies (to refine once upstream dependencies are confirmed)
  propagatedBuildInputs = with python3Packages; [
    pygobject3
    pillow
    pyscreenshot
    opencv-python
    evdev
    dbus-python
  ];

  # Disable runtime dependency check to avoid strict version mismatch errors
  dontCheckRuntimeDeps = true;

  # Basic import check; adjust module name if upstream differs
  pythonImportsCheck = [ "hints" ];

  meta = with lib; {
    homepage = "https://github.com/AlfredoSequeida/hints";
    description = "Navigate GUI apps with keyboard hints (Linux)";
    mainProgram = "hints";
    platforms = platforms.linux;
    license = licenses.gpl3Only;
  };
}
