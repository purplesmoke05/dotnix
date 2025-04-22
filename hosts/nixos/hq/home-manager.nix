# Home Manager Configuration
# Personal user environment setup for the laptop
# - User-specific package management and configuration
# - Development environment and tools
# - Desktop environment and window manager
# - Japanese input method system
{ pkgs, username, ... }: {
  # Module Imports
  # Core configuration modules for different aspects of the system
  # - Development: Programming languages and tools
  # - CLI: Command-line utilities and shell configuration
  # - GUI: Graphical applications and themes
  # - Hyprland: Wayland compositor and window management
  imports = [
    ../../../home-manager/development/default.nix
    ../../../home-manager/cli/default.nix
    ../../../home-manager/gui/default.nix
    ../../../home-manager/gui/claude-desktop.nix
    ../../../home-manager/wm/hyprland/default.nix
    ../../../home-manager/mcp-servers/default.nix
  ];

  # Basic Home Configuration
  # User identity and state version settings
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "24.11";
  };
  programs.home-manager.enable = true;

  wayland.windowManager.hyprland.settings.monitor = [
    "HDMI-A-1,1920x1080@60,0x0,1"
    "DP-1,1920x1080@240,1920x0,1"
  ];
  wayland.windowManager.hyprland.settings.workspace = [
    /*"1,monitor:HDMI-A-1,default:true"
    "2,monitor:HDMI-A-1"
    "3,monitor:HDMI-A-1"
    "4,monitor:HDMI-A-1"
    "5,monitor:HDMI-A-1"
    "6,monitor:HDMI-A-1"
    "7,monitor:HDMI-A-1"
    "8,monitor:HDMI-A-1"
    "9,monitor:HDMI-A-1"
    "10,monitor:HDMI-A-1"

    "1,monitor:DP-1"
    "2,monitor:DP-1"
    "3,monitor:DP-1"
    "4,monitor:DP-1"
    "5,monitor:DP-1"
    "6,monitor:DP-1"
    "7,monitor:DP-1"
    "8,monitor:DP-1"
    "9,monitor:DP-1"
    "10,monitor:DP-1"*/
  ];
}
