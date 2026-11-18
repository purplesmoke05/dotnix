{ lib
, pkg-config
, meson
, ninja
, hyprland
, pixman
, libdrm
,
}:

# Build with Hyprland's own stdenv so the plugin uses the same compiler and C++ standard. / プラグインが同じコンパイラーと C++ の規格を使うよう、Hyprland 自身の stdenv でビルドする。
hyprland.stdenv.mkDerivation {
  pname = "hyprland-pip-drag";
  version = "2.0.0";

  src = ./.;

  nativeBuildInputs = [
    pkg-config
    meson
    ninja
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
