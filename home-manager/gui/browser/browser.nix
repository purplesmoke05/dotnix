{ config, pkgs, ... }: # Ensure config and pkgs are available if needed elsewhere

{
  programs = {
    google-chrome.enable = true;
    google-chrome.commandLineArgs = [ "--enable-features=UseOzonePlatform" "--ozone-platform=wayland" "--enable-wayland-ime=true" ];
    brave.enable = true;
    # Use Home Manager's intended option for command line args
    brave.commandLineArgs = [ "--enable-features=UseOzonePlatform" "--ozone-platform-hint=auto" ];
    firefox.enable = true;
  };

  # Add zen-browser package
  home.packages = [ pkgs.zen-browser ];

  # Removed ineffective brave-flags.conf definition
  # xdg.configFile."brave-flags.conf".text = ''
  #  ...
  # '';
}
