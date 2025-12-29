{ pkgs, config, ... }:
let
  hypridleConfigPath = "${config.xdg.configHome}/hypr/hypridle.conf";
  hyprctlBin = "/run/current-system/sw/bin/hyprctl";
in
{
  # Hypridle-driven idle DPMS. / Hypridle によるアイドル時の DPMS 制御。
  home.packages = [ pkgs.hypridle ];

  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
      after_sleep_cmd = ${hyprctlBin} dispatch dpms on
      ignore_dbus_inhibit = true
      ignore_systemd_inhibit = false
      ignore_wayland_inhibit = true
    }

    listener {
      timeout = 420
      on-timeout = ${hyprctlBin} dispatch dpms off
      on-resume = ${hyprctlBin} dispatch dpms on
    }
  '';

  systemd.user.services.hypridle = {
    Unit = {
      Description = "Hypridle idle handler for Hyprland";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.hypridle}/bin/hypridle --config ${hypridleConfigPath}";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };
}
