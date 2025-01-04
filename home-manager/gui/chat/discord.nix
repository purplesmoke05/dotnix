{pkgs, ...}: {
  # Discord Public Test Build installation
  home.packages = with pkgs; [
    discord-ptb
  ];

  # Discord client settings
  # - Skip automatic updates
  # - Enable developer tools for customization
  home.file.".config/discord/settings.json".text = ''
    {
      "SKIP_HOST_UPDATE": true,
      "DANGEROUS_ENABLE_DEVTOOLS_ONLY_ENABLE_IF_YOU_KNOW_WHAT_YOURE_DOING": true
    }
  '';

  # Custom CSS styling
  # - Set Migu 1P as the default font
  # - Improve font rendering
  programs.discocss = {
    enable = true;
    css = ''
      * {
        font-family: "Migu 1P" !important;
        -webkit-font-smoothing: subpixel-antialiased;
      }
    '';
  };
}