{ config, lib, pkgs, ... }:
let
  ghosttyCommand = [
    (lib.getExe config.programs.ghostty.package)
    "--gtk-single-instance=true"
  ];
in
{
  config = {
    home.packages = [
      (pkgs.writeShellApplication {
        name = "term-main";
        runtimeInputs = [ config.programs.ghostty.package ];
        text = ''
          exec ${lib.escapeShellArgs ghosttyCommand} "$@"
        '';
      })

      (pkgs.writeShellApplication {
        name = "term-ghostty";
        runtimeInputs = [ config.programs.ghostty.package ];
        text = ''
          exec ${lib.escapeShellArgs ghosttyCommand} "$@"
        '';
      })
    ];
  };
}
