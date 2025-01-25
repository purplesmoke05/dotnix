{ pkgs, ... }: {
  nixpkgs.overlays = [
    (import ./fix-ime.nix)
    (import ./force-wayland.nix)
  ];
}