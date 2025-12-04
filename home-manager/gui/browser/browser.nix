{ config, pkgs, ... }: # Ensure config and pkgs are available if needed elsewhere

{
  programs = {
    google-chrome.enable = true;
    google-chrome.commandLineArgs = [
      "--enable-features=UseOzonePlatform,VaapiVideoDecodeLinuxGL"
      "--ozone-platform=wayland"
      "--enable-wayland-ime=true"
      "--ignore-gpu-blocklist"
      "--enable-gpu-rasterization"
      "--enable-zero-copy"
    ];
    brave.enable = true;
    # Use Home Manager's intended option for command line args
    brave.commandLineArgs = [
      "--enable-features=UseOzonePlatform,VaapiVideoDecodeLinuxGL"
      "--ozone-platform=wayland"
      "--enable-wayland-ime=true"
      "--ignore-gpu-blocklist"
      "--enable-gpu-rasterization"
      "--enable-zero-copy"
    ];
    firefox.enable = true;
  };

  # Add zen-browser package and vdhcoapp (Video DownloadHelper companion app)
  home.packages = with pkgs; [
    vdhcoapp
  ];

  # Removed ineffective brave-flags.conf definition
  # xdg.configFile."brave-flags.conf".text = ''
  #  ...
  # '';
}
