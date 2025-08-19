{ pkgs, ... }:
{
  # Packages to be installed on the system
  environment.systemPackages = with pkgs; [
  ];

  # Enable automatic upgrade of the Nix daemon
  nix.package = pkgs.nix;

  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org" # home-managerのキャッシュ
    ];
  };

  ids.gids.nixbld = 350;

  # zsh configuration
  programs.zsh.enable = false;
  programs.fish.enable = true;

  # Allow non-free packages
  nixpkgs.config.allowUnfree = true;

  # Finder settings
  system.defaults.finder = {
    # Show all file extensions: When set to true, all file extensions are displayed.
    # This makes it easier to manage files by quickly identifying file types.
    AppleShowAllExtensions = true;

    # Show hidden files: When set to true, normally hidden files (those starting with a dot) are displayed.
    # This is useful for development work and detailed settings, but be cautious as unnecessary files may also be displayed during normal use.
    AppleShowAllFiles = true;

    # Hide desktop icons: When set to false, desktop icons are hidden.
    # This is useful for those who prefer a clean workspace or want to enforce desktop organization.
    CreateDesktop = false;

    # Disable warning when changing file extensions: When set to false, warnings are not displayed when changing file extensions.
    # This improves work efficiency when frequently changing file extensions.
    FXEnableExtensionChangeWarning = false;

    # Show path bar: When set to true, the file path is displayed at the bottom of the Finder window.
    # This makes it easier to understand the current location and navigate between directories.
    ShowPathbar = true;

    # Show status bar: When set to true, information about the selected item is displayed at the bottom of the Finder window.
    # This helps in file management by quickly checking information such as the number of files and their size.
    ShowStatusBar = true;
  };

  # Dock settings
  system.defaults.dock = {
    # Automatically hide the Dock: When set to true, the Dock is automatically hidden.
    # This expands the workspace by allowing more screen space.
    autohide = false;

    # Hide recently used applications: When set to false, recently used applications are not displayed in the Dock.
    # This is useful for maintaining privacy or keeping the Dock simple.
    show-recents = false;

    # Dock icon size: Set the icon size in pixels.
    # 50px is a moderate size that balances visibility and space-saving.
    tilesize = 50;

    # Dock icon magnification: When set to true, icons are magnified when hovered over.
    # This makes it easier to identify icons, especially when there are many applications in the Dock.
    magnification = true;

    # Icon size when magnified: Set the icon size in pixels when hovered over.
    # 64px is a moderate magnification size that makes icon details easier to see.
    largesize = 64;

    # Dock position: Can be set to "bottom", "left", or "right".
    # Placing it at the left gives a typical macOS appearance.
    orientation = "left";

    # Window minimization effect: "scale" uses the scale effect.
    # This effect is visually clear and makes the system feel more responsive.
    mineffect = "scale";

    # Disable application launch animation: When set to false, the launch animation is not displayed.
    # This makes the system feel more responsive, especially on lower-spec machines.
    launchanim = false;
  };

  # For backward compatibility (check changelog when changing)
  system.stateVersion = 4;

  # Target platform
  nixpkgs.hostPlatform = "aarch64-darwin";

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
    };
    brews = [
      "ethereum"
      "solidity"
    ];
    casks = [
      "wireshark"
      "spectacle"
      "raycast"
      "brave-browser"
    ];
  };
}
