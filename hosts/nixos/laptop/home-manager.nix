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
    ../../../home-manager/wm/hyprland/default.nix
  ];

  # Basic Home Configuration
  # User identity and state version settings
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "24.11";
  };
  programs.home-manager.enable = true;

  wayland.windowManager.hyprland.settings = {
    # Monitor configuration
    monitor = [
      "eDP-1,1920x1080@60,0x0,1" # Built-in laptop display (1920x1080, 60Hz)
    ];

    # Workspace monitor assignments
    workspace = [
      "1,monitor:eDP-1,default:true" # Primary workspace
      "2,monitor:eDP-1"
      "3,monitor:eDP-1"
      "4,monitor:eDP-1"
      "5,monitor:eDP-1"
      "6,monitor:eDP-1"
      "7,monitor:eDP-1"
      "8,monitor:eDP-1"
      "9,monitor:eDP-1"
      "10,monitor:eDP-1"
    ];
  };
}
