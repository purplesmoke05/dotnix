{ config, pkgs, ... }:

{
  programs.zellij = {
    enable = true;
    settings = {
      default_layout = "compact";
      default_shell = "fish";
      
      keybinds = {
        normal = {
            "bind \"Alt t\"" = { 
              "NewPane" = "Right";
              "Resize" = "Increase";
            };
        };
      };
      
      pane_frames = false;
    };
  };
}
