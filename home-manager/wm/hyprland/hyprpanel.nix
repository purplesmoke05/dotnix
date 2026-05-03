{ config, lib, pkgs, inputs, hostname, ... }:
let
  hasBattery = builtins.elem hostname [ "laptop" ];
in
{
  # Note: Hyprpanel module is now included in home-manager itself
  # No need to import from flake inputs anymore

  # Required packages for Hyprpanel functionality
  home.packages = with pkgs; [
    jq # JSON processor for updates module
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
              "clock" # Clock
              "notifications" # Notification center
            ];
          };
          # Remove media and clock only for mobile monitor to save horizontal room. / モバイルモニター向けにメディアと時計だけ省いて横幅を確保。
          layoutNoMediaClock = { showBattery ? hasBattery }: {
            "left" = [
              "dashboard"
              "workspaces"
              "windowtitle"
            ] ++ (if showBattery then [ "battery" ] else [ ]);
            "middle" = [ ];
            "right" = [
              "cpu"
              "ram"
              "volume"
              "network"
              "bluetooth"
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
          "DP-3" = layout { }; # Ultrawide monitor layout. / ウルトラワイド用レイアウト。
          "DP-2" = layoutNoMediaClock { }; # Mobile monitor layout without media and clock. / モバイル用にメディアと時計を省いたレイアウト。
          "0" = layout { }; # Default layout. / 既定レイアウト。
          "1" = layoutNoMediaClock { }; # Mobile monitor layout without media and clock. / モバイル用にメディアと時計を省いたレイアウト。
          "2" = layout { showBattery = false; }; # Layout without battery. / バッテリーなしレイアウト。
          "3" = layout { showBattery = false; }; # Layout without battery. / バッテリーなしレイアウト。
        };

      "theme.name" = "catppuccin_mocha";

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
