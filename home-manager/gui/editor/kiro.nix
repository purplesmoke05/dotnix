{ pkgs, ... }: {
  # Kiro text editor package
  home.packages = with pkgs; [
    kiro
  ];
}
