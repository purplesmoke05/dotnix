{
  programs = {
    google-chrome.enable = true;
    google-chrome.commandLineArgs = [ "--enable-features=UseOzonePlatform" "--ozone-platform=wayland" "--enable-wayland-ime=true" ];
    brave.enable = true;
    brave.commandLineArgs = [ "--enable-features=UseOzonePlatform" "--ozone-platform=wayland" "--enable-wayland-ime=true" ];
  };
}
