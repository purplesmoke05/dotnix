{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, wrapGAppsHook4
, gtk4
, libadwaita
, webkitgtk_6_0
, glib
, cairo
, pango
, gdk-pixbuf
, graphene
, libGL
, libxkbcommon
, wayland
, openssl
, fontconfig
, freetype
, harfbuzz
, glib-networking
}:

let
  version = "0.1.13";
  artifact = "limux-${version}-linux-x86_64.tar.gz";
in
stdenv.mkDerivation {
  pname = "limux";
  inherit version;

  src = fetchurl {
    url = "https://github.com/am-will/limux/releases/download/v${version}/${artifact}";
    sha256 = "1zqgj9qvhrv65j1in30ix6wvyilvx5dklkgyf3spnhv81c3rpkkn";
  };

  nativeBuildInputs = [ autoPatchelfHook wrapGAppsHook4 ];

  buildInputs = [
    stdenv.cc.cc.lib
    gtk4
    libadwaita
    webkitgtk_6_0
    glib
    cairo
    pango
    gdk-pixbuf
    graphene
    libGL
    libxkbcommon
    wayland
    openssl
    fontconfig
    freetype
    harfbuzz
    glib-networking
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 limux $out/bin/limux
    install -Dm644 lib/libghostty.so $out/lib/limux/libghostty.so

    mkdir -p $out/share
    cp -r share/limux $out/share/
    install -Dm644 share/applications/dev.limux.linux.desktop \
      $out/share/applications/dev.limux.linux.desktop
    install -Dm644 share/metainfo/dev.limux.linux.metainfo.xml \
      $out/share/metainfo/dev.limux.linux.metainfo.xml
    if [ -d share/icons ]; then
      cp -r share/icons $out/share/
    fi

    runHook postInstall
  '';

  appendRunpaths = [ "${placeholder "out"}/lib/limux" ];

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "$out/lib/limux"
    )
  '';

  meta = {
    description = "GPU-accelerated terminal multiplexer for Linux (libghostty-based)";
    homepage = "https://github.com/am-will/limux";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "limux";
  };
}
