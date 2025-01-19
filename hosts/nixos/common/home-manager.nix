{ config, pkgs, ... }:

{
  # User Packages
  # Core user-level packages and tools
  # - Input Method: Complete Fcitx5 + Mozc setup for Japanese
  # - Theme Integration: Icon themes and GUI toolkits
  # - Configuration Tools: Input method setup utilities
  # - Exa MCP Server Package
  home.packages = with pkgs; [
    nodePackages.exa-mcp-server
    papirus-icon-theme
    mozc
    fcitx5-mozc
    fcitx5-gtk
    libsForQt5.fcitx5-qt
    qt6Packages.fcitx5-qt
    fcitx5-configtool
    appimage-run
    awscli2
 ];

  # Environment Variables
  # Input method integration across different toolkits
  # - X11/Wayland compatibility
  # - Qt/GTK framework integration
  # - Game engine (SDL/GLFW) support
  home.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    NIXOS_OZONE_WL = "1";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";
    FCITX_ADDON_DIRS = "${pkgs.fcitx5-with-addons}/lib/fcitx5:${pkgs.fcitx5-mozc}/lib/fcitx5";
    DISABLE_KWALLET = "1";
    FCITX_LOG_LEVEL = "debug";
    QT_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
  };

  # Cursor Theme
  # System-wide cursor appearance configuration
  # - Adwaita theme for consistency
  # - GTK integration enabled
  home.pointerCursor = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
    x11 = {
      enable = true;
      defaultCursor = "Adwaita";
    };
    gtk.enable = true;
  };

  # Input Method Configuration Files
  # Detailed Fcitx5 and Mozc configuration
  xdg.configFile = {
    # Input Method Profile
    # Default input method and keyboard layout settings
    "fcitx5/profile" = {
      force = true;
      text = ''
        [Groups/0]
        # Group Name
        Name=Default
        # Layout
        Default Layout=jp
        # Default Input Method
        DefaultIM=mozc

        [Groups/0/Items/0]
        # Name
        Name=mozc
        # Layout
        Layout=jp

        [GroupOrder]
        0=Default
      '';
    };

    # Fcitx5 Global Configuration
    # System-wide input method behavior settings
    "fcitx5/config" = {
      force = true;
      text = ''
        [Hotkey]
        EnumerateKeys=
        TriggerKeys=

        [Behavior]
        DefaultInputMethod=mozc
        ShareInputState=All
      '';
    };

    # Classic UI Configuration
    # Visual appearance and behavior settings
    "fcitx5/conf/classicui.conf" = {
      text = ''
        Vertical Candidate List=False
        PerScreenDPI=True
        WheelForPaging=True
        Font="Noto Sans CJK JP 10"
        Theme=default
      '';
    };

    # Mozc Key Bindings
    # Custom key mappings for IME control
    # - Henkan key: Enable IME
    # - Muhenkan key: Disable IME
    "mozc/keymap.tsv" = {
      force = true;
      text = ''
        status	key	command
        DirectInput	Henkan	IMEOn
        Composition	Henkan	IMEOn
        Conversion	Henkan	IMEOn
        Precomposition	Henkan	IMEOn
        DirectInput	Muhenkan	IMEOff
        Composition	Muhenkan	IMEOff
        Conversion	Muhenkan	IMEOff
        Precomposition	Muhenkan	IMEOff
      '';
    };

    # XIM Configuration
    # Legacy application support settings
    "fcitx5/conf/xim.conf" = {
      force = true;
      text = ''
        UseOnTheSpot=True
      '';
    };

    # Mozc Database
    # Pre-configured Mozc settings database
    "mozc/config1.db" = {
      force = true;
      source = ./mozc/config1.db;
    };

    # Mozc Input Method Configuration
    # Detailed Mozc behavior settings
    "fcitx5/conf/mozc.conf" = {
      force = true;
      text = ''
        InitialMode=Direct
        InputState="Follow Global Configuration"
        Vertical=True
        ExpandMode="On Focus"
        PreeditCursorPositionAtBeginning=False
        ExpandKey=Control+Alt+H
      '';
    };
  };

  # Qt Framework Configuration
  # Qt application theming and integration
  # - GTK theme compatibility
  # - Dark theme preference
  qt = {
    enable = true;
    platformTheme = {
      name = "gtk";
    };
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };

  # Exa MCP Server Service
  # Systemd user service configuration for Exa MCP server
  # - Automatic startup after network
  # - Development API key configuration
  # - Automatic restart on failure
  systemd.user.services.exa-mcp-server = {
    Unit = {
      Description = "Exa MCP Server";
      After = "network.target";
      StartLimitIntervalSec = 3600;
      StartLimitBurst = 5;
      DefaultState = "inactive";
    };

    Service = {
      Type = "simple";
      Environment = "EXA_API_KEY=dummy-api-key-for-development";
      ExecStart = "${pkgs.nodePackages.exa-mcp-server}/bin/exa-mcp-server";
      Restart = "always";
      RestartSec = "10";
      StartLimitAction = "none";
    };

    Install = {
      WantedBy = [ "default.target" ];
      Enable = false;
    };
  };

  programs.ssh = {
    enable = true;

    extraConfig = ''
      AddKeysToAgent yes
      ServerAliveInterval 60
    '';

  };
}
