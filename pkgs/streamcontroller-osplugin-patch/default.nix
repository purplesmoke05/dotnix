{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "streamcontroller-osplugin-patch";
  version = "1";

  src = ./.;
  dontBuild = true;

  installPhase = ''
    install -D -m 0644 RunCommand.py \
      $out/share/streamcontroller/plugins/com_core447_OSPlugin/actions/RunCommand/RunCommand.py
  '';

  meta = with lib; {
    description = "Patched StreamController OSPlugin RunCommand action";
    platforms = platforms.linux;
  };
}
