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
    # --- Cli ---
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

    # -- Font ---
    nerd-fonts.hack

    # --- Dev ---
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
  ];

  # User information
  home.username = username;
# Using lib.mkForce to address a known bug in nix-darwin (Issue #682).
  # https://github.com/LnL7/nix-darwin/issues/682
  # Once this bug is fixed, it may be possible to simply set "/Users/${username}".
  home.homeDirectory = lib.mkForce "/Users/${username}";

  home.sessionPath = [
    "/Users/${username}/.nix-profile/bin"
  ];
  # users.users.${username}.shell = pkgs.fish;


  # Version of home-manager (be cautious when changing)
  home.stateVersion = "24.11";

  # Enable home-manager
  programs.home-manager.enable = true;
}
