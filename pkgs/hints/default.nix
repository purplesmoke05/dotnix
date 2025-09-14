{ lib
, python3Packages
, fetchFromGitHub
, wrapGAppsHook
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

  # (We patch upstream file in postPatch below to improve Wayland/Hyprland auto-detection)

  # Build using PEP 517 (pyproject.toml) if present; this is compatible with both
  # setuptools and poetry projects
  format = "pyproject";
  nativeBuildInputs = [ wrapGAppsHook ]
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

  # gappsWrapperArgs で十分にラップするため postInstall の追加ラップは不要

  # Ensure wrapGAppsHook includes all required GI typelib and data dirs
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix GI_TYPELIB_PATH : "${lib.getLib gtk3}/lib/girepository-1.0:${lib.getLib pango}/lib/girepository-1.0:${lib.getLib gdk-pixbuf}/lib/girepository-1.0:${lib.getLib at-spi2-core}/lib/girepository-1.0:${lib.getLib harfbuzz}/lib/girepository-1.0:${lib.getLib gtk-layer-shell}/lib/girepository-1.0:${lib.getLib glib}/lib/girepository-1.0:${lib.getLib gobject-introspection}/lib/girepository-1.0"
      --prefix XDG_DATA_DIRS : "${gtk3}/share:${gdk-pixbuf}/share:${glib}/share"
    )
  '';

  # Remove custom post-install hook that tries to write intoホームやsystemdに書き込む処理
  # Nix ビルドでは副作用を持てないため無効化
  postPatch = ''
    substituteInPlace setup.py \
      --replace 'cmdclass={"install": PostInstallCommand},' ""

    # Wayland 自動判定の候補に小文字 hyprland を追加
    substituteInPlace hints/hints.py \
      --replace 'supported_wayland_wms = {"sway", "Hyprland", "plasmashell"}' 'supported_wayland_wms = {"sway", "Hyprland", "hyprland", "plasmashell"}'

    # HINTS_WINDOW_SYSTEM 環境変数で強制指定できるようにする
    sed -i '0,/if not window_system_id:/{s//env_choice = __import__("os").getenv("HINTS_WINDOW_SYSTEM", "")\n    if env_choice:\n        window_system_id = env_choice\n    if not window_system_id:/}' hints/hints.py

    # さらに、検出できなかった場合の Hyprland 環境変数フォールバックを追加
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

  # 追加の postFixup は不要（gapps のラップに統一）

  # Runtime dependencies (to refine once upstream dependencies are confirmed)
  propagatedBuildInputs = with python3Packages; [
    pygobject3
    pillow
    pyscreenshot
    opencv-python
    evdev
    dbus-python
  ];

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
