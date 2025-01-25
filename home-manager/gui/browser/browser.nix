{
  programs = {
    google-chrome.enable = true;
    google-chrome.commandLineArgs = [ "--enable-features=UseOzonePlatform" "--ozone-platform=x11" ];
    brave.enable = true;
    brave.commandLineArgs = [ "--enable-features=UseOzonePlatform" "--ozone-platform=x11" ];
  };
}
