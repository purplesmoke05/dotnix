{ pkgs, lib, username, ... }:

{
  imports = [
    ./../../home-manager/cli/git
    ./../../home-manager/cli/terminal/alacritty.nix
    ./../../home-manager/cli/terminal/starship.nix
    ./../../home-manager/cli/terminal/zellij.nix
    ./../../home-manager/cli/terminal/ghostty.nix
    ./../../home-manager/cli/terminal/carapace.nix
    ./../../home-manager/cli/terminal/nushell.nix
    ./../../home-manager/cli/terminal/fish.nix
    ./../../home-manager/cli/alternative.nix
    ./../../home-manager/gui/editor/vscode
  ];
  home.packages = with pkgs; [
    # CLI tools / CLI ツール
    fd
    jq
    peco
    fzf
    ripgrep
    zstd
    btop
    htop
    iftop
    ctop
    dive
    uv
    foundry

    # Fonts / フォント
    nerd-fonts.hack

    # Dev tools / 開発ツール
    neovim
    gh
    ghq
    go
    deno
    zig
    volta
    rustup
    pulumi
    postgresql
    libpq
    libpq.pg_config
    copilot-cli
  ];

  # User information / ユーザー情報
  home.username = username;
  # Use mkForce to dodge nix-darwin bug #682. / nix-darwin のバグ #682 回避で mkForce を使用。
  home.homeDirectory = lib.mkForce "/Users/${username}";

  home.sessionPath = [
    "/Users/${username}/.nix-profile/bin"
  ];
  # users.users.${username}.shell = pkgs.fish;

  # Home Manager version / Home Manager バージョン
  home.stateVersion = "24.11";

  # Enable Home Manager / Home Manager を有効化
  programs.home-manager.enable = true;
}
