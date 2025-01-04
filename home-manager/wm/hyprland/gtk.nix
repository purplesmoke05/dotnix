{ pkgs, ... }: {
  # GTK theme and configuration
  gtk = {
    enable = true;

    # Icon theme configuration
    iconTheme = {
      name = "Papirus-Dark"; # Dark variant of Papirus icon theme
      package = pkgs.papirus-icon-theme;
    };

    # GTK theme configuration
    theme = {
      name = "Tokyonight-Dark"; # Dark variant of Tokyo Night theme
      package = pkgs.tokyonight-gtk-theme;
    };

    # GTK3 specific settings
    gtk3.extraConfig = {
      gtk-im-module = "fcitx"; # Input method module for GTK3 applications
    };

    # GTK4 specific settings
    gtk4.extraConfig = {
      gtk-im-module = "fcitx"; # Input method module for GTK4 applications
    };
  };
}