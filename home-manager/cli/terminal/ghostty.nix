{ config, pkgs, lib, ... }:
let
  ghosttyExe = lib.getExe config.programs.ghostty.package;
in
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

    settings =
      {
        window-padding-color = "extend-always";
        theme = "TokyoNight Night";
        background-opacity = 0.3;
        background-opacity-cells = true;
        background-blur = false;
        scrollback-limit = 100000000;
        desktop-notifications = true;
        font-family = [
          "Hack Nerd Font"
          "Noto Sans CJK JP"
        ];
        font-size = if pkgs.stdenv.isDarwin then 12 else 10;
        font-thicken = false;
        cursor-style = "bar";
        cursor-style-blink = true;
        cursor-opacity = 1;
        macos-option-as-alt = true;
        macos-window-shadow = true;
        macos-titlebar-style = "tabs";
        macos-non-native-fullscreen = true;
        macos-titlebar-proxy-icon = "hidden";
        window-padding-x = 4;
        window-padding-y = 2;
        window-theme = "ghostty";
        window-titlebar-background = "#1a1b26";
        window-titlebar-foreground = "#c0caf5";
        window-height = 26;
        window-width = 90;
        window-padding-balance = false;
        window-inherit-working-directory = true;
        window-decoration = true;
        window-show-tab-bar = "auto";
        copy-on-select = true;
        confirm-close-surface = true;
        clipboard-paste-protection = true;
        clipboard-trim-trailing-spaces = true;
        gtk-tabs-location = "bottom";
        gtk-titlebar-style = "native";
        gtk-toolbar-style = "flat";
        gtk-wide-tabs = false;

        adjust-cell-width = "0%";
        font-feature = "-dlig";
        auto-update-channel = "tip";
        keybind = [
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
          "alt+t=new_tab"
          "ctrl+q=previous_tab"
          "ctrl+bracket_right=next_tab"
        ];
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        gtk-custom-css = [ "${config.xdg.configHome}/ghostty/ghostty-gtk.css" ];
      };
  };

  xdg.configFile = lib.mkIf pkgs.stdenv.isLinux {
    "ghostty/ghostty-gtk.css".text = ''
      window.window tabbar > revealer > box.box {
        background-color: #0f111a;
        color: #a9b1d6;
        box-shadow: inset 0 1px #24283b;
        padding: 2px 6px;
      }

      window.window tabbar tabbox {
        min-height: 26px;
        padding-top: 1px;
        padding-bottom: 1px;
      }

      window.window tabbar tabbox > separator {
        margin-top: 4px;
        margin-bottom: 4px;
        opacity: 0;
      }

      window.window tabbar tabbox > tabboxchild {
        border-radius: 0;
      }

      window.window tabbar tab {
        min-height: 20px;
        margin: 0 1px 0 0;
        padding: 0 10px;
        border-radius: 0;
        background-color: #161925;
        color: #9aa5ce;
        box-shadow: none;
      }

      window.window tabbar tab:hover {
        background-color: #1f2335;
        color: #c0caf5;
      }

      window.window tabbar tab:active {
        background-color: #24283b;
        color: #c0caf5;
      }

      window.window tabbar tab:selected {
        background-color: #9ece6a;
        color: #11121a;
      }

      window.window tabbar tab:selected:hover,
      window.window tabbar tab:selected:active {
        background-color: #a7d97c;
        color: #11121a;
      }

      window.window tabbar tab .tab-title {
        font-weight: 600;
      }

      window.window tabbar tab button.image-button,
      window.window tabbar tab button.tab-close-button {
        min-width: 18px;
        min-height: 18px;
        padding: 0;
      }

      window.window tabbar .start-action,
      window.window tabbar .end-action {
        padding: 2px 3px;
      }
    '';
  };

  xdg.dataFile = lib.mkIf pkgs.stdenv.isLinux {
    "applications/com.mitchellh.ghostty.quick.left.desktop".text = ''
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=Ghostty Quick Left
      Comment=Quick terminal window
      TryExec=${ghosttyExe}
      Exec=${ghosttyExe} --gtk-single-instance=false
      Icon=com.mitchellh.ghostty
      Categories=System;TerminalEmulator;
      Keywords=terminal;tty;pty;
      StartupNotify=true
      StartupWMClass=com.mitchellh.ghostty.quick.left
      Terminal=false
      NoDisplay=true
    '';

    "applications/com.mitchellh.ghostty.quick.right.desktop".text = ''
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=Ghostty Quick Right
      Comment=Quick terminal window
      TryExec=${ghosttyExe}
      Exec=${ghosttyExe} --gtk-single-instance=false
      Icon=com.mitchellh.ghostty
      Categories=System;TerminalEmulator;
      Keywords=terminal;tty;pty;
      StartupNotify=true
      StartupWMClass=com.mitchellh.ghostty.quick.right
      Terminal=false
      NoDisplay=true
    '';
  };
}
