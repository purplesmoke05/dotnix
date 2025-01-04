{ pkgs, ... }: {
  programs = {
    # Rofi: Application launcher and window switcher
    rofi = {
      enable = true;
      package = pkgs.rofi-wayland; # Use Wayland-compatible version
      terminal = "${pkgs.alacritty}/bin/alacritty"; # Default terminal for terminal commands
      theme = builtins.toString ./rofi.rasi; # Custom theme file

      # Additional configuration options
      extraConfig = {
        modi = "run,drun,window"; # Available modes
        icon-theme = "Papirus"; # Icon theme for application entries
        show-icons = true; # Display application icons
        drun-display-format = "{icon} {name}"; # Format for application entries
        location = 0; # Center of the screen
        disable-history = false; # Keep command history
        hide-scrollbar = true; # Clean interface without scrollbar
        display-drun = "   Apps "; # Applications menu label
        display-run = "   Run "; # Run command label
        display-window = " 﩯  Window"; # Window switcher label
        display-Network = " 󰤨  Network"; # Network menu label
        sidebar-mode = true; # Enable sidebar mode for categories
      };
    };
  };
}