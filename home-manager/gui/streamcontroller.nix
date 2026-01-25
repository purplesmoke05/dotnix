{ lib, pkgs, ... }:

lib.mkIf pkgs.stdenv.isLinux {
  # Keep StreamController OSPlugin patched file in place. / StreamController OSPlugin のパッチ済みファイルを配置。
  home.file.".var/app/com.core447.StreamController/data/plugins/com_core447_OSPlugin/actions/RunCommand/RunCommand.py" = {
    source = "${pkgs.streamcontroller-osplugin-patch}/share/streamcontroller/plugins/com_core447_OSPlugin/actions/RunCommand/RunCommand.py";
    force = true;
  };

}
