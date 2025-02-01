{pkgs, ...}: {
  # Deepin Music installation
  home.packages = with pkgs; [
    youtube-music
  ];
}