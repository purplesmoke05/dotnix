{pkgs, config, lib, ...}:
let
  # Create custom discocss package (for discord-ptb)
  customDiscocss = pkgs.discocss.override {
    discordAlias = true;
    discord = pkgs.discord-ptb;
  };
in {
  # Discord Public Test Build installation
  home.packages = with pkgs; [
    discord-ptb
    customDiscocss  # Add custom package
  ];

  # Discord client settings
  # - Skip automatic updates
  # - Enable developer tools for customization
  home.file.".config/discord-ptb/settings.json".text = ''
    {
      "SKIP_HOST_UPDATE": true,
      "DANGEROUS_ENABLE_DEVTOOLS_ONLY_ENABLE_IF_YOU_KNOW_WHAT_YOURE_DOING": true
    }
  '';

  # Disable discocss module (using custom package instead)
  programs.discocss.enable = false;

  # Configure script to apply CSS at startup
  home.file.".config/discocss/custom.css".text = ''
    * {
      font-family: "Migu 1P" !important;
      -webkit-font-smoothing: subpixel-antialiased;
    }
  '';
}