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
    ../../home-manager/development/default.nix
    ../../home-manager/cli/default.nix
    ../../home-manager/gui/default.nix
    ../../home-manager/wm/hyprland/default.nix
  ];

  # Basic Home Configuration
  # User identity and state version settings
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "24.11";
  };
  programs.home-manager.enable = true;
}
