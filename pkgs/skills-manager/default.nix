{ lib
, appimageTools
, fetchurl
, libglvnd
, mesa
, libGL
, libdrm
, libxkbcommon
, vulkan-loader
, wayland
, xorg
}:

let
  pname = "skills-manager";
  version = "1.14.1";

  src = fetchurl {
    url = "https://github.com/xingkongliang/skills-manager/releases/download/v${version}/skills-manager_${version}_amd64.AppImage";
    sha256 = "0x0g0ir40nasd161j7ar0r9xj874zsi0yvp716v5maprhvm1ly99";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = _: [
    libglvnd
    mesa
    libGL
    libdrm
    libxkbcommon
    vulkan-loader
    wayland
    xorg.libxcb
    xorg.libX11
    xorg.libXrandr
    xorg.libXcursor
    xorg.libXi
    xorg.libXfixes
    xorg.libXdamage
    xorg.libXcomposite
    xorg.libXext
    xorg.libXrender
    xorg.libXtst
  ];

  extraInstallCommands = ''
    # FHS env's bundled mesa mismatches the host DRI driver, so EGL aborts.
    # Pull NixOS's hardware GPU driver in via /run/opengl-driver and force
    # webkit2gtk away from the dmabuf path that breaks under XWayland.
    mv $out/bin/skills-manager $out/bin/.skills-manager-wrapped
    cat > $out/bin/skills-manager <<EOF
    #!/bin/sh
    export LD_LIBRARY_PATH=/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}
    export WEBKIT_DISABLE_DMABUF_RENDERER=''${WEBKIT_DISABLE_DMABUF_RENDERER:-1}
    export WEBKIT_DISABLE_COMPOSITING_MODE=''${WEBKIT_DISABLE_COMPOSITING_MODE:-1}
    export GDK_BACKEND=''${GDK_BACKEND:-x11}
    exec $out/bin/.skills-manager-wrapped "\$@"
    EOF
    chmod +x $out/bin/skills-manager

    install -Dm644 ${appimageContents}/skills-manager.desktop \
      $out/share/applications/skills-manager.desktop
    substituteInPlace $out/share/applications/skills-manager.desktop \
      --replace 'Exec=AppRun' 'Exec=skills-manager'
    cp -r ${appimageContents}/usr/share/icons $out/share/
  '';

  meta = {
    description = "Desktop app to manage, sync, and organize AI agent skills across 15+ coding tools (Claude Code, Codex, Copilot, Cursor, ...)";
    homepage = "https://github.com/xingkongliang/skills-manager";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "skills-manager";
  };
}
