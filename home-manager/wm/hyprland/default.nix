{ pkgs, inputs, lib, ... }: {
  imports = [
    ./rofi.nix
    ./hyprpanel.nix
    ./gtk.nix
    ./wpaperd.nix
  ];

  # Essential packages for Hyprland environment
  home.packages = with pkgs; [
    brightnessctl # Screen brightness control
    grimblast # Screenshot utility
    swappy # Screenshot editor
    zenity # Dialog boxes for screenshots
    hyprpicker # Color picker
    bemoji # Emoji selector
    pamixer # Audio volume control
    playerctl # Media player control
    swww # Wallpaper manager
    wayvnc # VNC server
    wev # Debug key events
    wireplumber # Screen sharing support
    wf-recorder # Screen recording
    wl-clipboard # Clipboard manager
    cliphist # Clipboard history
    polkit # Authentication agent
    hyprpolkitagent # Password prompts
    libsecret # Secret service
    networkmanagerapplet # Network management GUI
    bluez # Bluetooth support
    hyprlandPlugins.hyprsplit # Window splitting plugin
    (pkgs.writeShellApplication {
      name = "quick-term";
      runtimeInputs = with pkgs; [ jq foot zellij ];
      bashOptions = [ "pipefail" ];
      text = ''
        # shellcheck disable=SC2009
        _pid="$(hyprctl clients -j | jq -r '.[] | select(.class == "foot-quick") | .pid')"

        if [ -n "$_pid" ]; then
          curr_focused="$(hyprctl activewindow -j | jq -r '.class')"
          if [ "$curr_focused" = "foot-quick" ]; then
            kill -9 "$_pid"
          else
            hyprctl dispatch focuswindow pid:"$_pid"
          fi
        else
          foot -a "foot-quick" -e zellij attach -c quick-term >/dev/null 2>&1 &
          exit 0
        fi
      '';
    })
  ];

  wayland.windowManager.hyprland = {
    enable = true;

    systemd.enable = true;
    systemd.enableXdgAutostart = true;

    settings = {
      # Basic Hyprland configuration
      "$mainMod" = "ALT"; # Main modifier key
      "$term" = "foot -e zellij"; # Default terminal

      # Hyprspace configuration
      "plugin:hyprspace" = {
        speed = "0.5";                   # アニメーション速度
        transition = "wipe";             # トランジションエフェクト (wipe, slide, none)
        workspaces = "10";              # 仮想デスクトップの数
        gesture_sensitivity = "1.0";     # ジェスチャー感度
      };

      "plugin:hyprsplit:persistent_workspaces" = true;
      "plugin:hyprsplit:num_workspaces" = 10;

      # Environment variables for proper integration
      env = [
        "XMODIFIERS, @im=fcitx" # Input method configuration
        "QT_QPA_PLATFORM,wayland" # Force Qt to use Wayland
        "QT_QPA_PLATFORMTHEME,qt5ct" # Qt theme configuration
        "QT_STYLE_OVERRIDE,Adwaita-Dark" # Qt style override
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1" # Disable Qt window decorations
        "NIXOS_OZONE_WL,1" # Force Wayland for Chromium-based applications
      ];

      # Input device configuration
      input = {
        kb_layout = "jp"; # Japanese keyboard layout
        kb_model = ""; # No specific keyboard model
        kb_variant = ""; # No layout variant
        kb_options = ""; # No additional options
        follow_mouse = 2; # Enable hover scroll without focus
        repeat_rate = 50; # Key repeat rate
        repeat_delay = 200; # Delay before key repeat starts
      };

      # Window appearance settings
      general = {
        gaps_in = 4; # Inner gaps between windows
        gaps_out = 8; # Outer gaps to screen edges
        border_size = 2; # Window border width
      };

      # Application-specific window rules
      windowrule = [
        "float,^(pavucontrol)$" # Audio control in floating mode
        "float,^(nm-connection-editor)$" # Network manager in floating mode
      ];

      windowrulev2 = [
        "float,class:^()$,title:^(Picture in picture)$"
        "float,class:^(brave)$,title:^(Save File)$"
        "float,class:^(brave)$,title:^(Open File)$"
        "float,class:^(blueman-manager)$"
        "float,class:^(xdg-desktop-portal-gtk)$"
        "float,class:^(xdg-desktop-portal-kde)$"
        "float,class:^(xdg-desktop-portal-hyprland)$"
        "float,class:^(zenity)$"
        "float,class:^()$,title:^(Steam - Self Updater)$"
        "float,class:^(pavucontrol)$"
        "float,class:^()$,title:^(Playwright Inspector)$"

        # rulev2 for foot
        "opacity 0.9 0.9, class:^(foot-quick)$"
        "float, class:^(foot-quick)$"
        "size 98% 40%, class:^(foot-quick)$"
        "move 1% 45px, class:^(foot-quick)$"
        "noshadow, class:^(foot-quick)$"
        "pin,class:^(foot-quick)$"
        "animation slideDown,class:^(foot-quick)$"

        "workspace 10 silent:split:0:0,class:^(discord)$"
      ];

      # Keybindings
      bind = [
        # System controls
        "$mainMod,Return,exec,$term" # Launch terminal
        "$mainMod SHIFT,Q,killactive," # Close window
        "$mainMod SHIFT, E, exec, ${pkgs.hyprpanel}/bin/hyprpanel -t powerdropdownmenu" # Power menu
        "$mainMod,M,exit," # Exit Hyprland
        "$mainMod SHIFT, F,fullscreen," # Toggle fullscreen
        "$mainMod SHIFT, P, pin" # Pin window
        "$mainMod,E,exec,nautilus" # File manager
        "CTRL, 4, exec,rofi -show drun" # Application launcher
        "CTRL, 1, exec,bemoji -t -c -e -n" # Emoji picker
        "$mainMod,P,pseudo," # Pseudo tiling

        # Utility controls
        "$mainMod SHIFT, c, exec, hyprpicker --autocopy" # Color picker

        # Window focus
        "$mainMod, j, movefocus, l" # Focus left
        "$mainMod, k, movefocus, d" # Focus down
        "$mainMod, l, movefocus, u" # Focus up
        "$mainMod, semicolon, movefocus, r" # Focus right
        "$mainMod, Tab, cyclenext" # Next window
        "$mainMod SHIFT, Tab, cyclenext, prev" # Previous window

        # Window movement
        "$mainMod SHIFT, j, movewindow, l" # Move left
        "$mainMod SHIFT, k, movewindow, d" # Move down
        "$mainMod SHIFT, l, movewindow, u" # Move up
        "$mainMod SHIFT, semicolon, movewindow, r" # Move right

        # Monitor control
        "$mainMod, Tab, exec, hyprctl monitors -j|jq 'map(select(.focused|not).activeWorkspace.id)[0]'|xargs hyprctl dispatch workspace"

        # Screenshot controls
        '', Print, exec, grimblast save output - | swappy -f - -o /tmp/screenshot.png && zenity --question --text="Save?" && cp /tmp/screenshot.png $HOME/Pictures/$(date +%Y-%m-%dT%H:%M:%S).png''
        ''$mainMod, Print, exec, grimblast save active - | swappy -f - -o /tmp/screenshot.png && zenity --question --text="Save?" && cp /tmp/screenshot.png "$HOME/Pictures/$(date +%Y-%m-%dT%H:%M:%S).png"''
        ''$mainMod SHIFT, s, exec, grimblast save area - | swappy -f - -o /tmp/screenshot.png && zenity --question --text="Save?" && cp /tmp/screenshot.png "$HOME/Pictures/$(date +%Y-%m-%dT%H:%M:%S).png"''

        # Workspace switching (commented out in favor of split workspace plugin)
        # "$mainMod,1,workspace,1"
        # "$mainMod,2,workspace,2"
        # "$mainMod,3,workspace,3"
        # "$mainMod,4,workspace,4"
        # "$mainMod,5,workspace,5"
        # "$mainMod,6,workspace,6"
        # "$mainMod,7,workspace,7"
        # "$mainMod,8,workspace,8"
        # "$mainMod,9,workspace,9"

        # Move window to workspace (commented out in favor of split workspace plugin)
        # "$mainMod SHIFT,1,movetoworkspace,1"
        # "$mainMod SHIFT,2,movetoworkspace,2"
        # "$mainMod SHIFT,3,movetoworkspace,3"
        # "$mainMod SHIFT,4,movetoworkspace,4"
        # "$mainMod SHIFT,5,movetoworkspace,5"
        # "$mainMod SHIFT,6,movetoworkspace,6"
        # "$mainMod SHIFT,7,movetoworkspace,7"
        # "$mainMod SHIFT,8,movetoworkspace,8"
        # "$mainMod SHIFT,9,movetoworkspace,9"

        # Volume controls
        ", XF86AudioLowerVolume, exec, pamixer -ud 3 && pamixer --get-volume > /tmp/$HYPRLAND_INSTANCE_SIGNATURE.wob"
        ", XF86AudioRaiseVolume, exec, pamixer -ui 3 && pamixer --get-volume > /tmp/$HYPRLAND_INSTANCE_SIGNATURE.wob"
        ", XF86AudioMute, exec, amixer sset Master toggle | sed -En '/\[on\]/ s/.*\[([0-9]+)%\].*/\1/ p; /\[off\]/ s/.*/0/p' | head -1 > /tmp/$HYPRLAND_INSTANCE_SIGNATURE.wob"

        # Media playback controls
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"

        # Brightness controls
        ", XF86MonBrightnessUp, exec, brightnessctl s +5%"
        ", XF86MonBrightnessDown, exec, brightnessctl s 5%-"

        # Workspace navigation (commented out)
        # "SUPER,tab,workspace,e+1"
        # "SUPER SHIFT,tab,workspace,e-1"
        "CTRL, 3, exec, quick-term"

        # Hyprspace controls
        "$mainMod, bracketleft, exec, hyprspace workspace -1"   # 前のワークスペースへ
        "$mainMod, bracketright, exec, hyprspace workspace +1"  # 次のワークスペースへ
        "$mainMod SHIFT, bracketleft, exec, hyprspace move -1"  # ウィンドウを前のワークスペースへ移動
        "$mainMod SHIFT, bracketright, exec, hyprspace move +1" # ウィンドウを次のワークスペースへ移動
      ] ++ [
          "$mainMod, 0, split:workspace, 10"
          "$mainMod SHIFT, 0, split:movetoworkspace, 10"
      ] ++ (builtins.concatLists (
            builtins.genList (
              x:
              let
                ws = builtins.toString (x + 1);
              in
                [
                  "$mainMod, ${ws}, split:workspace, ${ws}"
                  "$mainMod SHIFT, ${ws}, split:movetoworkspace, ${ws}"
                ]
            ) 9
          ));

      # Animation configuration
      animations = {
        enabled = true;
        bezier = [
          "myBezier, 0.05, 0.9, 0.1, 1.05"
        ];
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "workspaces, 1, 6, default"
        ];
      };

      "exec-once" = [
        "hyprctl dispatch exec [workspace 1 silent:split:0:0] ${pkgs.code-cursor}/bin/cursor"
        "hyprctl dispatch exec [workspace 11 silent:split:0:0] ${pkgs.brave}/bin/brave"
        "hyprctl dispatch exec [workspace 12 silent:split:0:0] ${pkgs.foot}/bin/foot"
        "${pkgs.discord-ptb}/bin/discordptb"
        "hyprpanel"
      ];
    };

    # Hyprland plugins
    plugins = [
      # inputs.Hyprspace.packages.${pkgs.system}.Hyprspace
      pkgs.hyprlandPlugins.hyprsplit
    ];
  };
}
