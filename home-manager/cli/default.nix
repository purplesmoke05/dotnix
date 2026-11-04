{ pkgs, ... }: {
  # Command-line interface configurations
  # - Git and GitHub CLI tools
  # - Alacritty terminal emulator
  # - Starship shell prompt
  imports = [
    ./git/default.nix
    ./terminal/starship.nix
    ./terminal/ghostty.nix
    ./terminal/launcher.nix
    ./terminal/fish.nix
    ./terminal/carapace.nix
    ./file-manager.nix
    ./alternative.nix
  ];
}
