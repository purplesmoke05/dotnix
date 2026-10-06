{ lib
, stdenvNoCC
, fetchurl
, runCommand
, bintools
, dpkg
, autoPatchelfHook
, makeWrapper
, copyDesktopItems
, makeDesktopItem
, alsa-lib
, at-spi2-atk
, at-spi2-core
, atk
, cairo
, cups
, dbus
, expat
, gcc-unwrapped
, glib
, gtk3
, libX11
, libxcb
, libXcomposite
, libXdamage
, libXext
, libXfixes
, libXrandr
, libxkbcommon
, libgbm
, nspr
, nss
, pango
, # Libs-only build of systemd, which avoids pulling the whole systemd closure. / systemd 全体の closure を避ける libs-only ビルド。
  systemdLibs
, libglvnd
, libsecret
, libnotify
, libpulseaudio
, libayatana-appindicator
, libXcursor
, pipewire
, wayland
, # `orca serve` and the computer-use surface shell out to these. / `orca serve` と computer-use がこれらを呼び出す。
  git
, xclip
, xdotool
, xdg-utils
, xvfb-run
, # Wayland-native Computer Use backend; see computer-use-wayland.py. / Wayland ネイティブの Computer Use backend。computer-use-wayland.py を参照。
  grim
, wtype
, dotool
, wl-clipboard
, # Drop the session-inherited capabilities in the launcher; see the capdrop shims below. / 起動時にセッション継承の capability を落とす。下の capdrop shim を参照。
  util-linux
, runtimeShell
, # Provide XDG_ICON_DIRS and GSETTINGS_SCHEMAS_PATH. / XDG_ICON_DIRS と GSETTINGS_SCHEMAS_PATH を供給する。
  adwaita-icon-theme
, gsettings-desktop-schemas
, # Linux Computer Use drives the desktop through the bundled runtime.py, which imports Atspi/Gdk via PyGObject. / Linux の Computer Use は同梱 runtime.py が PyGObject 経由で Atspi/Gdk を import してデスクトップを操作する。
  # gobject-introspection builds $GI_TYPELIB_PATH from buildInputs so the wrapper only has to forward it. / gobject-introspection が buildInputs から $GI_TYPELIB_PATH を構築するため、wrapper はそれを転送するだけでよい。
  gobject-introspection
, python3
, harfbuzz
}:

let
  version = "1.4.221";

  # Python with PyGObject plus the GTK stack whose typelibs runtime.py imports. / runtime.py が import する typelib 群を持つ PyGObject 入り Python。
  computerUsePython = python3.withPackages (ps: [ ps.pygobject3 ]);

  # The sidecar spawns bare `python3` by name, so this must be the python3 the wrapper exposes. / sidecar は名前だけの `python3` を spawn するため、wrapper が公開する python3 がこれである必要がある。
  computerUsePath = lib.makeBinPath [ computerUsePython ];

  computerUseToolsPath = lib.makeBinPath [ grim wtype dotool wl-clipboard ];

  # Nix system to Debian package architecture. / Nix system を Debian パッケージの arch に対応付ける。
  architectures = {
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
  };

  architecture = architectures.${stdenvNoCC.hostPlatform.system}
    or (throw "orca-ide: unsupported system ${stdenvNoCC.hostPlatform.system}");

  hashes = {
    amd64 = "sha256-QkRerOzPcFuOaxq+hDzKkOht/rjb+7Qu1H7Rr5PFV2s=";
    arm64 = "sha256-uQmv8tiU/caymKyPsUykFkPpp6KLp7LZTHyDGo3wJqg=";
  };

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-ide_${version}_${architecture}.deb";
    hash = hashes.${architecture};
  };

  # orcad-template is the daemon payload Orca copies to SSH remote hosts, and it refuses to deploy unless every file matches the sha256 in orcad-template.json. / orcad-template は Orca が SSH リモートへ配布する daemon 一式で、全ファイルが orcad-template.json の sha256 と一致しないと配布を拒否する。
  # Its prebuilt binaries target other platforms and libcs (musl, darwin, win32), so it lives in a derivation without fixupPhase, out of reach of strip, RPATH shrinking and autoPatchelf. / 同梱バイナリは他プラットフォームや別 libc（musl・darwin・win32）向けのため、fixupPhase を持たない derivation に置き、strip・RPATH 縮小・autoPatchelf の対象から外す。
  orcadTemplate = runCommand "orca-ide-orcad-template-${version}"
    {
      nativeBuildInputs = [ dpkg python3 ];
    } ''
    dpkg-deb --fsys-tarfile ${src} | tar -x ./opt/Orca/resources/orcad-template
    cp -a opt/Orca/resources/orcad-template $out

    # Fail here rather than when Orca first connects to a remote host. / リモートへの初回接続時ではなくここで失敗させる。
    python3 - $out <<'PY'
    import hashlib
    import json
    import pathlib
    import sys

    root = pathlib.Path(sys.argv[1])
    manifest = json.loads((root / "orcad-template.json").read_text())
    expected = dict(manifest["commonSha256"])
    for target, entry in manifest["targets"].items():
        for name, digest in entry["files"].items():
            expected[f"targets/{target}/{name}"] = digest
        if entry.get("browserName"):
            expected[f"targets/{target}/{entry['browserName']}"] = entry["browserSha256"]
    bad = [
        name
        for name, digest in sorted(expected.items())
        if hashlib.sha256((root / name).read_bytes()).hexdigest() != digest
    ]
    if bad:
        sys.exit("orcad-template files differ from orcad-template.json: " + ", ".join(bad))
    print(f"verified {len(expected)} orcad-template files")
    PY
  '';

  desktopItem = makeDesktopItem {
    name = "orca-ide";
    desktopName = "Orca";
    genericName = "Agentic Development Environment";
    comment = "Next-gen IDE for parallel agentic development";
    exec = "orca-ide %U";
    icon = "orca-ide";
    categories = [ "Development" ];
    # Electron reports WM_CLASS=orca while the executable is orca-ide, so the dock only groups the window with this value. / Electron の WM_CLASS は orca、実行ファイルは orca-ide のため、dock のグループ化にはこの値が必要。
    startupWMClass = "orca";
    mimeTypes = [ "x-scheme-handler/orca" ];
  };
in
stdenvNoCC.mkDerivation {
  pname = "orca-ide";
  inherit version src;

  nativeBuildInputs = [
    bintools
    dpkg
    autoPatchelfHook
    copyDesktopItems
    gobject-introspection
    makeWrapper
  ];

  buildInputs = [
    adwaita-icon-theme
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gcc-unwrapped.lib
    glib
    gsettings-desktop-schemas
    gtk3
    harfbuzz
    libgbm
    libX11
    libxcb
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libxkbcommon
    nspr
    nss
    pango
    systemdLibs
  ];

  # These are dlopen()ed at runtime and absent from DT_NEEDED, so they must be listed to reach the RUNPATH. / 実行時に dlopen され DT_NEEDED に現れないため、RUNPATH へ載せるには明示が必要。
  # libglvnd instead goes on the wrapper's LD_LIBRARY_PATH: ANGLE's bundled libEGL.so dlopen()s the native libEGL.so.1, and a RUNPATH on that object alone does not survive fixup. / libglvnd は wrapper の LD_LIBRARY_PATH に置く。ANGLE 同梱の libEGL.so が native な libEGL.so.1 を dlopen し、その object 単体の RUNPATH は fixup を生き残らないため。
  # Without it Chromium falls back to SwiftShader and renders the WebGL terminal on the CPU. / これが無いと Chromium は SwiftShader に落ち、WebGL ターミナルが CPU 描画になる。
  runtimeDependencies = [
    libayatana-appindicator
    libnotify
    libpulseaudio
    libsecret
    libXcursor
    pipewire
    wayland
  ];

  desktopItems = [ desktopItem ];

  unpackPhase = ''
    runHook preUnpack
    dpkg -x $src unpacked
    runHook postUnpack
  '';

  installPhase = ''
        runHook preInstall

        # Keep the upstream opt/Orca layout because bundled libs (libffmpeg.so), resources/, and app.asar.unpacked resolve relative to the binary. / 同梱 lib（libffmpeg.so）・resources/・app.asar.unpacked が実行ファイル相対で解決するため、upstream の opt/Orca 構成を維持する。
        mkdir -p $out/lib $out/bin $out/share
        cp -a unpacked/opt/Orca $out/lib/Orca
        cp -a unpacked/usr/share/icons $out/share/icons

        # Swap in the untouched template; fixup's find and autoPatchelf do not descend through this symlink. / 未加工のテンプレートに差し替える。fixup の find と autoPatchelf はこの symlink の先へ降りない。
        rm -r $out/lib/Orca/resources/orcad-template
        ln -s ${orcadTemplate} $out/lib/Orca/resources/orcad-template

        # chrome-sandbox needs setuid root, which a store path can never have; Electron falls back to user namespaces. / chrome-sandbox は setuid root を要するが store path では不可能なため、Electron の user namespace へ委ねる。
        rm -f $out/lib/Orca/chrome-sandbox

        chmod +x $out/lib/Orca/orca-ide $out/lib/Orca/resources/bin/orca-ide

        # Provider that swaps the bundled XTest-bound input and X11-only screenshot for grim/wtype/dotool. / 同梱の XTest 依存入力と X11 専用スクリーンショットを grim/wtype/dotool に差し替える provider。
        install -Dm644 ${./computer-use-wayland.py} $out/libexec/computer-use-wayland.py
        chmod +x $out/libexec/computer-use-wayland.py
        # Compile without emitting bytecode so no __pycache__ commits a build path into the output. / ビルドパスを埋め込む __pycache__ を残さないよう、bytecode を書かずにコンパイルする。
        PROVIDER="$out/libexec/computer-use-wayland.py" ${computerUsePython}/bin/python3 -B -c '
          import os
          path = os.environ["PROVIDER"]
          compile(open(path, encoding="utf-8").read(), path, "exec")
        '

        # Hyprland is granted cap_sys_nice through NixOS security.wrappers, and that wrapper raises the
        # capability into the ambient set, which every process started from the session inherits. / Hyprland は NixOS の security.wrappers で cap_sys_nice を与えられ、その wrapper は権限を ambient set へ昇格させるため、セッションで起動する全プロセスが継承する。
        # xdg-desktop-portal then cannot open /proc/<pid>/root for those processes (the ptrace-style check refuses a target holding capabilities the caller lacks), so it denies file dialogs with AccessDenied and no dialog ever appears. / その結果ポータルは /proc/<pid>/root を開けず（呼び出し元が持たない capability を持つ相手は ptrace 相当の検査で拒否される）、AccessDenied でファイルダイアログを拒否し、ダイアログが一切出なくなる。
        # Dropping the inherited capabilities in the launcher is safe because Hyprland resets child scheduling to SCHED_OTHER after fork. / 子プロセスの scheduling は Hyprland が fork 後に SCHED_OTHER へ戻すため、起動時に継承権限を落としても支障はない。
        cat > $out/libexec/orca-ide-capdrop <<'CAPDROP'
    #!${runtimeShell}
    exec ${lib.getExe' util-linux "setpriv"} --ambient-caps=-all --inh-caps=-all ${placeholder "out"}/lib/Orca/orca-ide "$@"
    CAPDROP
        chmod +x $out/libexec/orca-ide-capdrop

        cat > $out/libexec/orca-capdrop <<'CAPDROP'
    #!${runtimeShell}
    exec ${lib.getExe' util-linux "setpriv"} --ambient-caps=-all --inh-caps=-all ${placeholder "out"}/lib/Orca/resources/bin/orca-ide "$@"
    CAPDROP
        chmod +x $out/libexec/orca-capdrop

        makeWrapper "$out/libexec/orca-ide-capdrop" "$out/bin/orca-ide" \
          --suffix PATH : "${
            lib.makeBinPath [
              git
              xclip
              xdg-utils
              xdotool
              xvfb-run
            ]
          }" \
          --suffix PATH : "${computerUsePath}:${computerUseToolsPath}" \
          --set ORCA_COMPUTER_DESKTOP_SCRIPT_PROVIDER_PATH "$out/libexec/computer-use-wayland.py" \
          --prefix GI_TYPELIB_PATH : "$GI_TYPELIB_PATH" \
          --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libglvnd ]}" \
          --prefix XDG_DATA_DIRS : "$XDG_ICON_DIRS:$GSETTINGS_SCHEMAS_PATH" \
          --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

        # The shim re-execs the Electron binary under ELECTRON_RUN_AS_NODE on the CLI entrypoint; upstream's deb exposes it on PATH from postinst. / shim は Electron を ELECTRON_RUN_AS_NODE で CLI entrypoint に再実行する。upstream の deb は postinst で PATH に公開する。
        # This wraps it as `orca`, the name the docs use. / ここではドキュメント記載の `orca` として公開する。
        makeWrapper "$out/libexec/orca-capdrop" "$out/bin/orca" \
          --suffix PATH : "${
            lib.makeBinPath [
              git
              xclip
              xdg-utils
              xdotool
              xvfb-run
            ]
          }" \
          --suffix PATH : "${computerUsePath}:${computerUseToolsPath}" \
          --set ORCA_COMPUTER_DESKTOP_SCRIPT_PROVIDER_PATH "$out/libexec/computer-use-wayland.py" \
          --prefix GI_TYPELIB_PATH : "$GI_TYPELIB_PATH"

        runHook postInstall
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck
    version_output="$(HOME="$TMPDIR" "$out/bin/orca" --version)"
    if [[ "$version_output" != "${version}" ]]; then
      echo "orca --version reported '$version_output', expected '${version}'" >&2
      exit 1
    fi

    # The Computer Use runtime imports these namespaces; a missing typelib is silent until an agent tries to use the desktop. / Computer Use runtime はこれらを import する。typelib 欠落はエージェントがデスクトップを使うまで表面化しない。
    ${computerUsePython}/bin/python3 - <<'PY'
    import gi
    gi.require_version("Atspi", "2.0")
    gi.require_version("Gdk", "3.0")
    gi.require_version("GdkPixbuf", "2.0")
    from gi.repository import Atspi, Gdk, GdkPixbuf  # noqa: F401
    PY

    # Loading the provider also asserts the bundled runtime still exposes every function it overrides, so an Orca bump fails here instead of at runtime. / provider の読み込みは上書き対象の関数が同梱 runtime に残っていることも検査するため、Orca 更新時の破損は実行時ではなくここで検出される。
    # PATH mirrors the wrapper's so the capability probe reflects the deployed environment. / PATH は wrapper と揃え、capability 検査が実環境を反映するようにする。
    PATH="${computerUseToolsPath}:${computerUsePath}:$PATH" ORCA_PROVIDER="$out/libexec/computer-use-wayland.py" PYTHONDONTWRITEBYTECODE=1 ${computerUsePython}/bin/python3 - <<'PY'
    import importlib.util
    import json
    import os

    spec = importlib.util.spec_from_file_location("provider", os.environ["ORCA_PROVIDER"])
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.install_overrides()
    capabilities = module.handshake_response()["supports"]
    assert capabilities["observation"]["screenshot"] is True, capabilities
    assert capabilities["actions"]["hotkey"] is True, capabilities
    assert capabilities["actions"]["pasteText"] is True, capabilities
    print(json.dumps(capabilities, separators=(",", ":"), sort_keys=True))
    PY

    runHook postInstallCheck
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Agent development environment for running a fleet of coding agents in parallel";
    longDescription = ''
      Orca runs coding agents such as Codex, Claude Code, OpenCode or Pi
      side-by-side, each in its own git worktree, and tracks them in one
      place.
    '';
    homepage = "https://onorca.dev";
    changelog = "https://github.com/stablyai/orca/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "orca-ide";
    platforms = lib.attrNames architectures;
  };
}
