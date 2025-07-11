{ config, pkgs, ... }:

{
  programs.zellij = {
    enable = true;
    enableFishIntegration = false;
    settings = {
      show_banner = false;
      show_startup_tips = false;
      default_layout = "compact";
      default_shell = "fish";

      keybinds = {
        normal = {
          "bind \"Ctrl g\"" = {
            "SwitchToMode" = "Locked";
          };
          "bind \"Alt t\"" = {
            "NewTab" = { };
          };
          "bind \"Ctrl q\"" = { "GoToPreviousTab" = { }; };
          "bind \"Ctrl [\"" = { "GoToNextTab" = { }; };
          "bind \"Ctrl ,\"" = { MoveFocus = "Left"; };
          "bind \"Ctrl .\"" = { MoveFocus = "Right"; };
          "unbind \"Ctrl p\"" = { };
          "unbind \"Ctrl n\"" = { };
          "unbind \"Ctrl b\"" = { };
        };
        locked = {
          "bind \"Ctrl g\"" = {
            "SwitchToMode" = "Normal";
          };
        };
      };

      pane_frames = false;
      copy_command = "wl-copy";
    };
  };

  # isucon layout definition
  xdg.configFile."zellij/layouts/isucon.kdl".text = ''
    // Layout for isucon project directories
    layout {
        // Split panes vertically
        pane split_direction="vertical" {
            // Pane 1: ~/Projects/.isucon
            pane {
                cwd "${config.home.homeDirectory}/Projects/.isucon"
            }
            // Pane 2: ~/Projects/isucon-setup
            pane {
                cwd "${config.home.homeDirectory}/Projects/isucon-setup"
            }
            // Pane 3: ~/Projects/
            pane {
                cwd "${config.home.homeDirectory}/Projects/"
            }
        }
    }
  '';
}
