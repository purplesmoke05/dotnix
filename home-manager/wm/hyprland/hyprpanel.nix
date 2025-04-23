{ pkgs, inputs, ... }: {
  # Import Hyprpanel module from flake inputs
  imports = [
    inputs.hyprpanel.homeManagerModules.hyprpanel
  ];

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
    gcolor3 # Color picker tool (re-added)
  ];

  # Hyprpanel configuration
  programs.hyprpanel = {
    overlay.enable = true; # Enable overlay features
    enable = true; # Enable Hyprpanel
    systemd.enable = true; # Enable systemd integration
    overwrite.enable = true; # Allow configuration overwrites

    # Panel appearance and behavior settings
    settings = {
      # Panel layout configuration
      layout = {
        "bar.layouts" =
          let
            # Define standard layout with optional battery indicator
            layout = { showBattery ? true }: {
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
      };

      theme.name = "catppuccin_mocha";

      # Updates module configuration
      bar.customModules.updates = {
        pollingInterval = 1440000; # Check updates every 24 hours
        updateCommand = "jq '[.[].cvssv3_basescore | to_entries | add | select(.value > 5)] | length' <<< $(vulnix -S --json)";
        icon = {
          updated = "󰋼"; # Icon for up-to-date system
          pending = "󰋼"; # Icon for pending updates
        };
      };

      # Theme settings
      theme = {
        bar = {
          floating = false; # Dock to screen edge
          buttons.enableBorders = true; # Show button borders
          transparent = true; # Enable transparency
          buttons.modules.ram.enableBorder = false; # Disable RAM module border
        };
        font.size = "14px"; # Font size
      };

      # Clock settings
      menus.clock = {
        time = {
          military = true; # 24-hour format
          hideSeconds = false; # Show seconds
        };
        weather.enabled = false; # Disable weather
      };
      bar.clock.format = "%y/%m/%d  %H:%M"; # Clock format

      # Media player settings
      bar.media = {
        show_active_only = true; # Only show active media
        format = "{title}"; # Display format
      };
      menus.media.displayTime = true; # Show playback time

      # Notification settings
      bar.notifications.show_total = false; # Hide notification count

      # Launcher settings
      bar.launcher.autoDetectIcon = true; # Auto-detect application icons

      # Battery settings
      bar.battery.hideLabelWhenFull = true; # Hide label when fully charged

      # Dashboard settings
      menus.dashboard = {
        controls.enabled = false; # Disable controls section
        shortcuts = {
          enabled = true; # Enable shortcuts
          right.shortcut1.command = "${pkgs.gcolor3}/bin/gcolor3"; # Color picker shortcut (corrected path)
        };
      };

      # Power settings
      menus.power.lowBatteryNotification = true; # Enable low battery alerts

      # Volume control settings
      bar.volume = {
        rightClick = "pactl set-sink-mute @DEFAULT_SINK@ toggle"; # Toggle mute
        middleClick = "pavucontrol"; # Open volume control
      };
    };
  };
}
