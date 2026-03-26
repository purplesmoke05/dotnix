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
    ./streamcontroller.nix
  ];

  # Additional GUI applications. / 追加の GUI アプリケーション。
  home.packages = with pkgs; [
    totem
    evince
    loupe
    parsec-bin
    remmina
    slack
    streamcontroller
    streamcontroller-hypr
  ];
}
