{ lib
, stdenv
, pkg-config
, meson
, ninja
, gcc14
, hyprland
, pixman
, libdrm
,
}:

stdenv.mkDerivation {
  pname = "hyprland-pip-drag";
  version = "1.1.0";

  src = ./.;

  nativeBuildInputs = [
    pkg-config
    meson
    ninja
    gcc14
  ];

  buildInputs = [
    hyprland.dev
    pixman
    libdrm
  ] ++ hyprland.buildInputs;

  meta = {
    description = "Move browser picture-in-picture windows and resize them at their current aspect ratio";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
