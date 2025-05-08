{ pkgs, lib, username, ... }:

{
  home.packages = with pkgs; [
    ripgrep
    fd
    jq
    neovim
    dive
    ctop
    htop
    gh
    ghq
    peco
    pulumi
    postgresql
    rustup
    fzf
    zstd
    btop
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

  # Version of home-manager (be cautious when changing)
  home.stateVersion = "24.11";

  # Enable home-manager
  programs.home-manager.enable = true;
}
