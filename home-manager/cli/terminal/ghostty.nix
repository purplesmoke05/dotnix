{ pkgs, ... }:
{
  xdg.configFile."ghostty/config".text = ''
    macos-option-as-alt = true
  '';
  programs.ghostty = {
    enable = false;

    package =
      if pkgs.stdenv.isLinux then
        pkgs.ghostty
      else if pkgs.stdenv.isDarwin then
        pkgs.brewCasks.ghostty
      else
        throw "unsupported system ${pkgs.stdenv.hostPlatform.system}";

    enableFishIntegration = true;

    settings = {
      window-decoration = "none";
      window-padding-color = "extend-always";
      theme = "catppuccin-mocha";
      background-opacity = 0.9;
      background-blur-radius = 20;
      font-size = if pkgs.stdenv.isDarwin then 16 else 12;
      font-thicken = true;
      font-feature = "-dlig";
    };
  };
}