{ ... }:

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
  };
}
