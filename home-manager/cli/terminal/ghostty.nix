{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;

    package =
      if pkgs.stdenv.isLinux then
        pkgs.ghostty
      else if pkgs.stdenv.isDarwin then
        pkgs.brewCasks.ghostty
      else
        throw "unsupported system ${pkgs.stdenv.hostPlatform.system}";

    enableFishIntegration = true;

    settings = {
      window-padding-color = "extend-always";
      theme = "catppuccin-mocha";
      background-opacity = 0.4;
      background-blur-radius = 0;
      scrollback-limit = 100000;
      font-size = if pkgs.stdenv.isDarwin then 12 else 11;
      font-thicken = true;
      macos-option-as-alt = true;
      macos-window-shadow = true;
      macos-titlebar-style = "tabs";
      macos-non-native-fullscreen = true;
      macos-titlebar-proxy-icon = "hidden";
      window-padding-x = 12;
      window-padding-y = 12;
      window-theme = "system";
      window-height = 26;
      window-width = 90;
      window-padding-balance = false;
      window-inherit-working-directory = true;
      window-decoration = true;
      copy-on-select = true;
      confirm-close-surface = true;
      clipboard-paste-protection = true;
      clipboard-trim-trailing-spaces = true;

      adjust-cell-width = "-7%";
      font-feature = "-dlig";
      auto-update-channel = "tip";

      # quick-terminal
      quick-terminal-position = "bottom";
      quick-terminal-animation-duration = 0;
      quick-terminal-screen = "mouse";
      quick-terminal-space-behavior = "remain";
      keybind = [
        "global:ctrl+5=toggle_quick_terminal"
        "ctrl+g=scroll_to_top"
        "ctrl+shift+g=scroll_to_bottom"
        "ctrl+shift+u=scroll_page_up"
        "ctrl+shift+d=scroll_page_down"
        "ctrl+shift+space=write_scrollback_file:open"
        "ctrl+equal=increase_font_size:1"
        "ctrl+minus=decrease_font_size:1"
        "ctrl+0=reset_font_size"
        "ctrl+alt+u=scroll_page_up"
        "ctrl+alt+d=scroll_page_down"
        "ctrl+shift+c=copy_to_clipboard"
        "ctrl+shift+v=paste_from_clipboard"
        "ctrl+shift+t=new_tab"
        "ctrl+shift+h=previous_tab"
        "ctrl+shift+l=next_tab"
      ];
    };
  };
}
