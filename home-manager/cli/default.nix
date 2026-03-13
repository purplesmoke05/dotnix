{ pkgs, ... }: {
  # Command-line interface configurations
  # - Git and GitHub CLI tools
  # - Alacritty terminal emulator
  # - Starship shell prompt
  imports = [
    ./git/default.nix
    ./terminal/alacritty.nix
    ./terminal/starship.nix
    ./terminal/ghostty.nix
    ./terminal/launcher.nix
    ./terminal/fish.nix
    ./terminal/carapace.nix
    ./terminal/nushell.nix
    ./alternative.nix
    ./voice-input.nix
  ];
}
