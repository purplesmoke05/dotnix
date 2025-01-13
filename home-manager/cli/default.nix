{pkgs, ...}: {
  # Command-line interface configurations
  # - Git and GitHub CLI tools
  # - Alacritty terminal emulator
  # - Starship shell prompt
  imports = [
    ./git/default.nix
    ./terminal/alacritty.nix
    ./terminal/starship.nix
    ./terminal/zellij.nix
    ./terminal/foot.nix
  ];
}
