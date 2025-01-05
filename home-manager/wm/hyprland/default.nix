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
    hyprlandPlugins.hyprspace # Virtual desktop plugin
    hyprlandPlugins.hyprsplit # Window splitting plugin
  ];

  wayland.windowManager.hyprland = {
    enable = true;

    systemd.enable = true;
    systemd.enableXdgAutostart = true;

    settings = {
      # Basic Hyprland configuration
      "$mainMod" = "ALT"; # Main modifier key
      "$term" = "alacritty"; # Default terminal

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
        follow_mouse = 0; # No focus follows mouse
        touchpad = {
          natural_scroll = true; # Natural scrolling direction
        };
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

        # Workspace navigation (commented out)
        # "SUPER,tab,workspace,e+1"
        # "SUPER SHIFT,tab,workspace,e-1"
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

      # Hardware control bindings
      bindle = [
        # Volume controls
        ", XF86AudioRaiseVolume, exec, pamixer -i 10"
        ", XF86AudioLowerVolume, exec, pamixer -d 10"

        # Brightness controls
        ", XF86MonBrightnessUp, exec, brightnessctl set +10%"
        ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"
      ];

      # Animation configuration
      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05"; # Custom animation curve
        animation = [
          "windows, 1, 7, myBezier" # Window animations
          "windowsOut, 1, 7, default, popin 80%" # Window closing animation
          "workspaces, 1, 6, default" # Workspace switching animation
        ];
      };
    };

    # Hyprland plugins
    plugins = [
      # inputs.hyprspace.packages.${pkgs.system}.Hyprspace
      # inputs.hyprsplit.packages.${pkgs.system}.hyprsplit
      pkgs.hyprlandPlugins.hyprspace
      pkgs.hyprlandPlugins.hyprsplit
    ];
  };
}
