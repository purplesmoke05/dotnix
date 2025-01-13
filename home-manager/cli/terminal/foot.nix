{ lib, config, ... }:
let
  # Tokyo Night テーマの色定義
  base = "#1a1b26";
  text = "#a9b1d6";
  n_black = "#32344a";
  n_red = "#f7768e";
  n_green = "#9ece6a";
  n_yellow = "#e0af68";
  n_blue = "#7aa2f7";
  n_magenta = "#ad8ee6";
  n_cyan = "#449dab";
  n_white = "#787c99";
in
{
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "Hack Nerd Font:size=10";
        term = "xterm-256color";
        dpi-aware = "no";
        pad = "4x2";
      };

      bell = {
        urgent = "no";
        notify = "no";
      };

      scrollback = {
        lines = 10000;
        multiplier = 3.0;
      };
      mouse = {
        hide-when-typing = false;
      };

      colors = {
        alpha = 0.93;
        foreground = "c0caf5";
        background = "1a1b26";

        # Normal/regular colors
        regular0 = "15161E";  # black
        regular1 = "f7768e";  # red
        regular2 = "9ece6a";  # green
        regular3 = "e0af68";  # yellow
        regular4 = "7aa2f7";  # blue
        regular5 = "bb9af7";  # magenta
        regular6 = "7dcfff";  # cyan
        regular7 = "a9b1d6";  # white

        # Bright colors
        bright0 = "414868";   # bright black
        bright1 = "f7768e";   # bright red
        bright2 = "9ece6a";   # bright green
        bright3 = "e0af68";   # bright yellow
        bright4 = "7aa2f7";   # bright blue
        bright5 = "bb9af7";   # bright magenta
        bright6 = "7dcfff";   # bright cyan
        bright7 = "c0caf5";   # bright white

        # Dimmed colors
        dim0 = "ff9e64";
        dim1 = "db4b4b";
      };

      cursor = {
        style = "beam";
        blink = "yes";
      };
    };
  };
}