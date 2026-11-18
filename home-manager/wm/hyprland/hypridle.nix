{ pkgs, config, ... }:
let
  hypridleConfigPath = "${config.xdg.configHome}/hypr/hypridle.conf";
  hyprctlBin = "/run/current-system/sw/bin/hyprctl";
  # hyprctl dispatch takes a Lua dispatcher expression. A script keeps its braces and quotes out of the hyprlang file. / hyprctl dispatch は Lua の dispatcher の式を受け取る。スクリプトにして、中括弧や引用符を hyprlang のファイルに書かないようにする。
  dpms = pkgs.writeShellScript "hypr-dpms" ''
    exec ${hyprctlBin} dispatch "hl.dsp.dpms({ action = '$1' })"
  '';
  dpmsOn = "${dpms} on";
  dpmsOff = "${dpms} off";
in
{
  # Hypridle-driven idle DPMS. / Hypridle によるアイドル時の DPMS 制御。
  home.packages = [ pkgs.hypridle ];

  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
      after_sleep_cmd = ${dpmsOn}
      ignore_dbus_inhibit = true
      ignore_systemd_inhibit = false
      ignore_wayland_inhibit = true
    }

    listener {
      timeout = 420
      on-timeout = ${dpmsOff}
      on-resume = ${dpmsOn}
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

  systemd.user.services.inhibit-idle-sleep = {
    Unit = {
      Description = "Inhibit idle and sleep while keep-awake is enabled";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionPathExists = "!%h/.config/hq/allow-sleep";
    };
    Service = {
      ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle:sleep --mode=block --why=\"keep-awake enabled\" ${pkgs.coreutils}/bin/sleep infinity";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };
}
