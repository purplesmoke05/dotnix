{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    nixos-artwork.wallpapers.binary-black
    nixos-artwork.wallpapers.gear
    nixos-artwork.wallpapers.gnome-dark
    nixos-artwork.wallpapers.dracula
    nixos-artwork.wallpapers.nineish
    nixos-artwork.wallpapers.nineish-solarized-dark
  ];

  home.activation.linkWallpapers = lib.hm.dag.entryAfter ["writeBoundary"] ''
    wallpaperDir="$HOME/Pictures/Wallpapers"
    mkdir -p "$wallpaperDir"

    find "$wallpaperDir" -type l -delete

    for pkg in ${toString [
      pkgs.nixos-artwork.wallpapers.binary-black
      pkgs.nixos-artwork.wallpapers.gear
      pkgs.nixos-artwork.wallpapers.gnome-dark
      pkgs.nixos-artwork.wallpapers.dracula
      pkgs.nixos-artwork.wallpapers.nineish
      pkgs.nixos-artwork.wallpapers.nineish-solarized-dark
    ]}; do
      find "$pkg" -name "*.png" -exec ln -sf {} "$wallpaperDir" \;
    done
  '';

  systemd.user.services.wpaperd = {
    Unit = {
      Description = "Wayland wallpaper daemon";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${pkgs.wpaperd}/bin/wpaperd";
      Restart = "always";
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };

  programs.wpaperd = {
    enable = true;
    settings = {
      default = {
        apply-shadow = false;
        path = "~/Pictures/Wallpapers";
        sorting = "random";
        duration = "30m";
      };
    };
  };
}
