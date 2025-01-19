{ pkgs, config, ... }:
let
  # Color scheme based on Tokyo Night theme
  # Source: https://github.com/zatchheems/tokyo-night-alacritty-theme

  # Normal color palette
  n_black = "#32344a";
  n_red = "#f7768e";
  n_green = "#9ece6a";
  n_yellow = "#e0af68";
  n_blue = "#7aa2f7";
  n_magenta = "#ad8ee6";
  n_cyan = "#449dab";
  n_white = "#787c99";

  # Bright color palette
  b_black = "#444b6a";
  b_red = "#ff7a93";
  b_green = "#b9f27c";
  b_yellow = "#ff9e64";
  b_blue = "#7da6ff";
  b_magenta = "#bb9af7";
  b_cyan = "#0db9d7";
  b_white = "#acb0d0";

  # Dim color palette
  d_black = "#282647";
  d_red = "#651900";
  d_green = "#00aa7f";
  d_yellow = "#7d7d00";
  d_blue = "#dea05e";
  d_magenta = "#006a80";
  d_cyan = "#c24141";
  d_white = "#7171a8";

  # Theme base colors
  base = "#1a1b26"; # Background color
  text = "#a9b1d6"; # Default text color
  subtext0 = "#A6ADC8"; # Secondary text color
  rosewater = "#F5E0DC"; # Accent color

  # Font configuration
  hack = "Hack Nerd Font";
in
{
  # Terminal compatibility packages
  home.packages = [
    pkgs.alacritty.terminfo
  ];
  home.sessionVariables.TERMINFO_DIRS = "${config.home.homeDirectory}/.nix-profile/share/terminfo";

  # Alacritty terminal configuration
  programs.alacritty = {
    enable = true;
    settings = {
      # Window appearance
      window = {
        padding = {
          x = 4;
          y = 2;
        };
        opacity = 0.93; # Window transparency
        blur = true; # Background blur effect
      };

      # Keyboard shortcuts
      keyboard = {
        bindings = [
          { key = "V"; mods = "Control | Shift"; action = "Paste"; }
        ];
      };

      # Color configuration
      colors = {
        # Primary colors
        primary = {
          background = base;
          foreground = text;
        };

        # Cursor colors
        cursor = {
          text = base;
          cursor = rosewater;
        };

        # Vi mode cursor colors
        vi_mode_cursor = {
          text = base;
          cursor = text;
        };

        # Search highlighting
        search = {
          matches = {
            foreground = base;
            background = subtext0;
          };
          focused_match = {
            foreground = base;
            background = "#A6E3A1";
          };
        };

        # Status bar colors
        footer_bar = {
          background = base;
          foreground = subtext0;
        };

        # Hint colors
        hints = {
          start = {
            foreground = base;
            background = "#F9E2AF";
          };
          end = {
            foreground = base;
            background = subtext0;
          };
        };

        # Selection colors
        selection = {
          text = base;
          background = rosewater;
        };

        # Standard color palettes
        normal = {
          black = n_black;
          red = n_red;
          green = n_green;
          yellow = n_yellow;
          blue = n_blue;
          magenta = n_magenta;
          cyan = n_cyan;
          white = n_white;
        };

        bright = {
          black = b_black;
          red = b_red;
          green = b_green;
          yellow = b_yellow;
          blue = b_blue;
          magenta = b_magenta;
          cyan = b_cyan;
          white = b_white;
        };

        dim = {
          black = d_black;
          red = d_red;
          green = d_green;
          yellow = d_yellow;
          blue = d_blue;
          magenta = d_magenta;
          cyan = d_cyan;
          white = d_white;
        };

        # Additional indexed colors
        indexed_colors = [
          { index = 16; color = "#FAB387"; }
          { index = 17; color = rosewater; }
        ];
      };

      # Font settings
      font = {
        normal = {
          family = hack;
          style = "Regular";
        };
        bold = {
          family = hack;
          style = "Bold";
        };
        italic = {
          family = hack;
          style = "Italic";
        };
        bold_italic = {
          family = hack;
          style = "Bold Italic";
        };
        size = 10.0;
      };

      # Scrollback configuration
      scrolling = {
        history = 100000; # Lines of scrollback
        multiplier = 3; # Scroll speed multiplier
      };
    };
  };
}
