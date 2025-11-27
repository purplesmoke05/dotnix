{ pkgs, inputs, hostname, ... }:
let
  # Force battery indicator on laptop host and fall back to sysfs when readable. / laptop ホストではバッテリー表示を強制し、読み取り可能な場合は sysfs 判定へフォールバック。
  hasBattery =
    let
      powerSupplyPath = "/sys/class/power_supply";
      batteryHosts = [ "laptop" ];
      sysfsBatteryCheck = builtins.tryEval (
        if builtins.pathExists powerSupplyPath then
          let
            entries = builtins.attrNames (builtins.readDir powerSupplyPath);
            batteryEntries = builtins.filter (name: builtins.match "^BAT" name != null) entries;
          in
          batteryEntries != [ ]
        else
          false
      );
      sysfsHasBattery =
        if sysfsBatteryCheck.success then sysfsBatteryCheck.value else false;
    in
    builtins.elem hostname batteryHosts || sysfsHasBattery;
in
{
  # Note: Hyprpanel module is now included in home-manager itself
  # No need to import from flake inputs anymore

  # Required packages for Hyprpanel functionality
  home.packages = with pkgs; [
    jq # JSON processor for updates module
    # vulnix # Security vulnerability scanner
    pavucontrol # PulseAudio volume control
    pulseaudio # Audio system
    brightnessctl # Brightness control
    power-profiles-daemon # Power management
    btop # System monitor
    hyprpanel # Main panel package
    gcolor3 # Color picker tool
  ];

  # Hyprpanel configuration
  programs.hyprpanel = {
    enable = true; # Enable Hyprpanel
    systemd.enable = true; # Enable systemd integration (default is true)
    # Note: overlay.enable has been removed - hyprpanel is now in nixpkgs
    # Note: overwrite.enable option doesn't exist in the module

    # Panel appearance and behavior settings
    settings = {
      # Panel layout configuration
      "bar.layouts" =
        let
          # Define standard layout with optional battery indicator
          layout = { showBattery ? hasBattery }: {
            "left" = [
              "dashboard" # System dashboard
              "workspaces" # Workspace indicator
              "windowtitle" # Active window title
              "updates" # System updates
              "storage" # Storage usage
            ] ++ (if showBattery then [ "battery" ] else [ ]);
            "middle" = [
              "media" # Media controls
            ];
            "right" = [
              "cpu" # CPU usage
              "ram" # Memory usage
              "volume" # Volume control
              "network" # Network status
              "bluetooth" # Bluetooth status
              "systray" # System tray
              "clock" # Clock
              "notifications" # Notification center
            ];
          };
          # Empty layout definition
          none = {
            "left" = [ ];
            "middle" = [ ];
            "right" = [ ];
          };
        in
        {
          "0" = layout { }; # Default layout
          "1" = layout { showBattery = false; }; # Layout without battery
          "2" = layout { showBattery = false; }; # Layout without battery
          "3" = layout { showBattery = false; }; # Layout without battery
        };

      "theme.name" = "catppuccin_mocha";

      # Updates module configuration
      "bar.customModules.updates.pollingInterval" = 1440000; # Check updates every 24 hours
      "bar.customModules.updates.updateCommand" = "jq '[.[].cvssv3_basescore | to_entries | add | select(.value > 5)] | length' <<< $(vulnix -S --json)";
      "bar.customModules.updates.icon.updated" = "󰋼"; # Icon for up-to-date system
      "bar.customModules.updates.icon.pending" = "󰋼"; # Icon for pending updates

      # Theme settings
      "theme.bar.floating" = false; # Dock to screen edge
      "theme.bar.buttons.enableBorders" = true; # Show button borders
      "theme.bar.transparent" = true; # Enable transparency
      "theme.bar.buttons.modules.ram.enableBorder" = false; # Disable RAM module border
      "theme.font.size" = "14px"; # Font size

      # Clock settings
      "menus.clock.time.military" = true; # 24-hour format
      "menus.clock.time.hideSeconds" = false; # Show seconds
      "menus.clock.weather.enabled" = false; # Disable weather
      "bar.clock.format" = "%y/%m/%d  %H:%M"; # Clock format

      # Media player settings
      "bar.media.show_active_only" = true; # Only show active media
      "bar.media.format" = "{title}"; # Display format
      "menus.media.displayTime" = true; # Show playback time

      # Notification settings
      "bar.notifications.show_total" = false; # Hide notification count

      # Launcher settings
      "bar.launcher.autoDetectIcon" = true; # Auto-detect application icons

      # Battery settings
      "bar.battery.hideLabelWhenFull" = true; # Hide label when fully charged

      # Dashboard settings
      "menus.dashboard.controls.enabled" = false; # Disable controls section
      "menus.dashboard.shortcuts.enabled" = true; # Enable shortcuts
      "menus.dashboard.shortcuts.right.shortcut1.command" = "${pkgs.gcolor3}/bin/gcolor3"; # Color picker shortcut

      # Power settings
      "menus.power.lowBatteryNotification" = true; # Enable low battery alerts

      # Volume control settings
      "bar.volume.rightClick" = "pactl set-sink-mute @DEFAULT_SINK@ toggle"; # Toggle mute
      "bar.volume.middleClick" = "pavucontrol"; # Open volume control
    };
  };

  # Run Hyprpanel under en_US to avoid locale-sensitive resource polling bug. / ロケール依存のリソース監視不具合を避けるため en_US で実行する。
  systemd.user.services.hyprpanel.Service.Environment = [
    "LANG=en_US.UTF-8"
    "LC_ALL=en_US.UTF-8"
  ];

}
