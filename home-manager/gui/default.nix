{ pkgs, ... }: {
  # GUI application configurations
  # - Web browser settings
  # - Neovim editor configuration
  # - Discord chat client
  imports = [
    ./browser/browser.nix
    ./editor/neovim.nix
    ./editor/antigravity.nix
    ./editor/kiro.nix
    ./editor/zed.nix
    ./editor/vscode/default.nix
    ./chat/discord.nix
    ./game/steam.nix
    ./music
  ];

  # Additional GUI applications
  # - Totem: Video player
  # - Evince: PDF viewer
  # - Parsec: Remote desktop
  # - Remmina: Remote desktop client
  # - Slack: Team communication
  home.packages = with pkgs; [
    totem
    evince
    parsec-bin
    remmina
    slack
    streamcontroller
  ];
}
