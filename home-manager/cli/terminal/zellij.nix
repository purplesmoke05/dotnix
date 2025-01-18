{ config, pkgs, ... }:

{
  programs.zellij = {
    enable = true;
    settings = {
      default_layout = "compact";
      default_shell = "fish";
      
      keybinds = {
        normal = {
            "bind \"Ctrl g\"" = {
              "SwitchToMode" = "Locked";
            };
            "bind \"Alt t\"" = { 
              "NewPane" = "Right";
              "Resize" = "Increase";
            };
            "unbind \"Ctrl p\""= {};
            "unbind \"Ctrl n\""= {};
            "unbind \"Ctrl b\""= {};
        };
        locked = {
            "bind \"Ctrl g\"" = {
              "SwitchToMode" = "Normal";
            };
        };
      };
      
      pane_frames = false;
      copy_commandd = "wl-copy";
    };
  };
}
