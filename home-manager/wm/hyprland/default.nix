{ pkgs, inputs, lib, hyprsplit, ... }: {
  imports = [
    ./rofi.nix
    ./ironbar.nix
    ./gtk.nix
    ./wpaperd.nix
    ./hypridle.nix
  ];

  # Hyprland essentials / Hyprland 基本ツール
  home.packages = with pkgs; [
    # Display & capture / 表示とキャプチャ
    brightnessctl
    grimblast
    swappy
    zenity
    hyprpicker
    wf-recorder

    # Input & clipboard / 入力とクリップボード
    bemoji
    wl-clipboard
    cliphist

    # Audio & media / オーディオとメディア
    pamixer
    playerctl
    wireplumber

    # System helpers / システム補助
    swww
    wayvnc
    wev
    polkit
    hyprpolkitagent
    libsecret
    networkmanagerapplet
    bluez
    (pkgs.writeShellApplication {
      name = "hypr-media";
      runtimeInputs = with pkgs; [
        brightnessctl
        coreutils
        gawk
        libnotify
        pamixer
      ];
      bashOptions = [ "nounset" "pipefail" ];
      text = ''
        action="''${1:-}"
        volume_notification_id=991049
        brightness_notification_id=991050

        send_notification() {
          _replace_id="$1"
          _icon="$2"
          _summary="$3"
          _body="$4"
          _value="$5"

          notify-send \
            --app-name="hypr-media" \
            --urgency=low \
            --expire-time=1000 \
            --replace-id="$_replace_id" \
            --icon="$_icon" \
            --hint=int:value:"$_value" \
            --transient \
            "$_summary" "$_body"
        }

        notify_volume() {
          if [ "$(pamixer --get-mute)" = "true" ]; then
            send_notification "$volume_notification_id" "audio-volume-muted-symbolic" "Volume" "Muted" 0
            return 0
          fi

          _volume="$(pamixer --get-volume)"

          case "$_volume" in
            ""|*[!0-9]*)
              return 0
              ;;
          esac

          _icon="audio-volume-low-symbolic"
          if [ "$_volume" -ge 67 ]; then
            _icon="audio-volume-high-symbolic"
          elif [ "$_volume" -ge 34 ]; then
            _icon="audio-volume-medium-symbolic"
          fi

          send_notification "$volume_notification_id" "$_icon" "Volume" "$_volume%" "$_volume"
        }

        has_backlight() {
          [ -d /sys/class/backlight ] && [ -n "$(ls -A /sys/class/backlight 2>/dev/null)" ]
        }

        get_brightness_percentage() {
          brightnessctl -m -c backlight info 2>/dev/null | awk -F, 'NR == 1 { gsub(/%/, "", $4); print $4 }'
        }

        notify_brightness() {
          if ! has_backlight; then
            return 0
          fi

          _brightness="$(get_brightness_percentage)"

          case "$_brightness" in
            ""|*[!0-9]*)
              return 0
              ;;
          esac

          send_notification "$brightness_notification_id" "display-brightness-symbolic" "Brightness" "$_brightness%" "$_brightness"
        }

        case "$action" in
          volume-down)
            pamixer -ud 3
            notify_volume
            ;;
          volume-up)
            pamixer -ui 3
            notify_volume
            ;;
          volume-mute)
            pamixer --toggle-mute
            notify_volume
            ;;
          brightness-up)
            if has_backlight; then
              brightnessctl -q -c backlight s +5%
              notify_brightness
            fi
            ;;
          brightness-down)
            if has_backlight; then
              brightnessctl -q -c backlight s 5%-
              notify_brightness
            fi
            ;;
          *)
            printf 'unknown action: %s\n' "$action" >&2
            exit 1
            ;;
        esac
      '';
    })
    (pkgs.writeShellApplication {
      name = "quick-term";
      runtimeInputs = with pkgs; [ coreutils jq ghostty ];
      bashOptions = [ "nounset" "pipefail" ];
      text = ''
        left_class="com.mitchellh.ghostty.quick.left"
        right_class="com.mitchellh.ghostty.quick.right"
        hidden_workspace="99"
        state_file="''${XDG_RUNTIME_DIR:-/tmp}/quick-term-last-focused-$UID"

        get_client_pid() {
          _class="$1"
          hyprctl clients -j | jq -r --arg class "$_class" 'first(.[] | select(.class == $class) | .pid) // empty'
        }

        get_client_workspace() {
          _class="$1"
          hyprctl clients -j | jq -r --arg class "$_class" 'first(.[] | select(.class == $class) | .workspace.name) // empty'
        }

        get_client_pinned() {
          _class="$1"
          hyprctl clients -j | jq -r --arg class "$_class" 'first(.[] | select(.class == $class) | (.pinned | tostring)) // empty'
        }

        is_quick_term_class() {
          case "$1" in
            "$left_class"|"$right_class")
              return 0
              ;;
            *)
              return 1
              ;;
          esac
        }

        remember_last_focused_quick_term() {
          _class="$1"

          if is_quick_term_class "$_class"; then
            printf '%s\n' "$_class" > "$state_file"
          fi
        }

        get_preferred_quick_term_class() {
          _class=""

          if [ -r "$state_file" ]; then
            IFS= read -r _class < "$state_file" || true
          fi

          if is_quick_term_class "$_class"; then
            printf '%s\n' "$_class"
            return 0
          fi

          printf '%s\n' "$left_class"
        }

        get_alternate_quick_term_class() {
          case "$1" in
            "$right_class")
              printf '%s\n' "$left_class"
              ;;
            *)
              printf '%s\n' "$right_class"
              ;;
          esac
        }

        launch_quick_term() {
          _class="$1"
          ghostty \
            --class="$_class" \
            --gtk-single-instance=false \
            --window-padding-y=2,32 \
            --background-opacity=0.85 \
            --background-opacity-cells=false \
            >/dev/null 2>&1 &
        }

        wait_for_client() {
          _class="$1"
          _attempt=0

          while [ "$_attempt" -lt 100 ]; do
            if [ -n "$(get_client_pid "$_class")" ]; then
              return 0
            fi

            sleep 0.05
            _attempt=$((_attempt + 1))
          done

          return 1
        }

        get_active_monitor() {
          _active_monitor="$(hyprctl activeworkspace -j | jq -r '.monitor // empty')"
          if [ -z "$_active_monitor" ]; then
            _active_monitor="$(hyprctl monitors -j | jq -r 'first(.[] | select(.focused == true) | .name) // empty')"
          fi

          printf '%s\n' "$_active_monitor"
        }

        get_quick_term_geometry_for_active_monitor() {
          _side="$1"
          _active_monitor="$(get_active_monitor)"

          if [ -z "$_active_monitor" ]; then
            return 0
          fi

          _geometry="$(
            hyprctl monitors -j | jq -r --arg monitor "$_active_monitor" --arg side "$_side" '
              first(.[] | select(.name == $monitor)) as $m
              | ($m.scale | tonumber) as $scale
              | ($m.transform | tonumber) as $transform
              | (if ($transform % 2) == 1 then ($m.height / $scale) else ($m.width / $scale) end | floor) as $logical_w
              | (if ($transform % 2) == 1 then ($m.width / $scale) else ($m.height / $scale) end | floor) as $logical_h
              | (($logical_w * 1 / 100) | floor) as $margin_x
              | (($logical_w * 1 / 100) | floor) as $gap
              | (((($logical_w - (2 * $margin_x) - $gap) / 2)) | floor) as $w
              | (($logical_h * 40 / 100) | floor) as $h
              | (($m.x + $margin_x) | floor) as $left_x
              | (($left_x + $w + $gap) | floor) as $right_x
              | (($m.y + ($logical_h * 55 / 100)) | floor) as $y
              | "\((if $side == "left" then $left_x else $right_x end) | floor) \($y) \($w) \($h)"
            '
          )"

          if [ -z "$_geometry" ]; then
            return 0
          fi

          printf '%s\n' "$_geometry"
        }

        append_batch_command() {
          _command="$1"

          if [ -z "$_command" ]; then
            return 0
          fi

          if [ -n "''${_batch_commands:-}" ]; then
            _batch_commands="$_batch_commands ; "
          fi

          _batch_commands="$_batch_commands$_command"
        }

        append_quick_term_pin_state_commands() {
          _desired="$1"
          shift

          for _class in "$@"; do
            _pid="$(get_client_pid "$_class")"
            _is_pinned_now="$(get_client_pinned "$_class")"

            if [ -z "$_pid" ]; then
              continue
            fi

            if [ "$_desired" = "true" ] && [ "$_is_pinned_now" != "true" ]; then
              append_batch_command "dispatch pin pid:$_pid"
            fi

            if [ "$_desired" = "false" ] && [ "$_is_pinned_now" = "true" ]; then
              append_batch_command "dispatch pin pid:$_pid"
            fi
          done
        }

        append_quick_term_show_commands() {
          _class="$1"
          _geometry="$2"
          _active_ws="$3"
          _pid="$(get_client_pid "$_class")"

          if [ -z "$_pid" ]; then
            return 0
          fi

          _ws="$(get_client_workspace "$_class")"
          if [ -n "$_active_ws" ] && [ "$_ws" != "$_active_ws" ]; then
            append_batch_command "dispatch movetoworkspacesilent $_active_ws,pid:$_pid"
          fi

          if [ -n "$_geometry" ]; then
            read -r _x _y _w _h <<< "$_geometry"
            append_batch_command "dispatch resizewindowpixel exact $_w $_h,pid:$_pid"
            append_batch_command "dispatch movewindowpixel exact $_x $_y,pid:$_pid"
          fi
        }

        append_quick_term_hide_commands() {
          _class="$1"
          _pid="$(get_client_pid "$_class")"

          if [ -z "$_pid" ]; then
            return 0
          fi

          append_batch_command "dispatch movetoworkspacesilent $hidden_workspace,pid:$_pid"
        }

        _focused_class="$(hyprctl activewindow -j | jq -r '.class // ""')"

        if is_quick_term_class "$_focused_class"; then
          remember_last_focused_quick_term "$_focused_class"
          _batch_commands=""
          append_quick_term_pin_state_commands "false" "$right_class" "$left_class"
          append_quick_term_hide_commands "$left_class"
          append_quick_term_hide_commands "$right_class"
          if [ -n "$_batch_commands" ]; then
            hyprctl --batch "$_batch_commands" >/dev/null 2>&1
          fi
          exit 0
        fi

        _need_wait_left=0
        _need_wait_right=0

        if [ -z "$(get_client_pid "$left_class")" ]; then
          launch_quick_term "$left_class"
          _need_wait_left=1
        fi

        if [ -z "$(get_client_pid "$right_class")" ]; then
          launch_quick_term "$right_class"
          _need_wait_right=1
        fi

        if [ "$_need_wait_left" -eq 1 ]; then
          wait_for_client "$left_class" || true
        fi

        if [ "$_need_wait_right" -eq 1 ]; then
          wait_for_client "$right_class" || true
        fi

        _active_ws="$(hyprctl activeworkspace -j | jq -r '.name // empty')"
        _left_geometry="$(get_quick_term_geometry_for_active_monitor "left")"
        _right_geometry="$(get_quick_term_geometry_for_active_monitor "right")"

        _batch_commands=""
        append_quick_term_show_commands "$left_class" "$_left_geometry" "$_active_ws"
        append_quick_term_show_commands "$right_class" "$_right_geometry" "$_active_ws"
        append_quick_term_pin_state_commands "true" "$right_class" "$left_class"

        _preferred_class="$(get_preferred_quick_term_class)"
        _preferred_pid="$(get_client_pid "$_preferred_class")"
        if [ -n "$_preferred_pid" ]; then
          append_batch_command "dispatch focuswindow pid:$_preferred_pid"
          remember_last_focused_quick_term "$_preferred_class"
        else
          _alternate_class="$(get_alternate_quick_term_class "$_preferred_class")"
          _alternate_pid="$(get_client_pid "$_alternate_class")"
          if [ -n "$_alternate_pid" ]; then
            append_batch_command "dispatch focuswindow pid:$_alternate_pid"
            remember_last_focused_quick_term "$_alternate_class"
          fi
        fi

        if [ -n "$_batch_commands" ]; then
          hyprctl --batch "$_batch_commands" >/dev/null 2>&1
        fi
      '';
    })

    (pkgs.writeShellApplication {
      name = "hints-once";
      runtimeInputs = with pkgs; [ util-linux ];
      bashOptions = [ "errexit" "nounset" "pipefail" ];
      text = ''
        #!/usr/bin/env bash
        # Single-instance guard using flock on XDG_RUNTIME_DIR / XDG_RUNTIME_DIR で flock による単一実行ガード
        lock_dir="''${XDG_RUNTIME_DIR:-/run/user/$UID}"
        lock_file="$lock_dir/hints-overlay.lock"
        exec ${pkgs.util-linux}/bin/flock -n "$lock_file" \
          env HINTS_WINDOW_SYSTEM=hyprland ${pkgs.hints}/bin/hints -m hint
      '';
    })

    (pkgs.writeShellApplication {
      name = "toggle-japanese-im";
      runtimeInputs = with pkgs; [ fcitx5 ];
      bashOptions = [ "errexit" "nounset" "pipefail" ];
      text = ''
        current_im="$(fcitx5-remote -n 2>/dev/null || true)"

        fcitx5-remote -o >/dev/null 2>&1 || true

        if [ "$current_im" = "hazkey" ]; then
          exec fcitx5-remote -s mozc
        fi

        exec fcitx5-remote -s hazkey
      '';
    })

    # No toggle helpers for hints; keep direct invocation from keybind / hints 用トグルは作成しない
  ];

  wayland.windowManager.hyprland = {
    enable = true;

    package = null;

    systemd.enable = true;
    systemd.enableXdgAutostart = true;

    settings = {
      # render.explicit_sync = 0; # Not available on 0.49.0 / Hyprland 0.49.0 では未対応
      xwayland = {
        use_nearest_neighbor = false;
        force_zero_scaling = true;
      };

      # Basic Hyprland config / Hyprland 基本設定
      "$mainMod" = "ALT";
      "$term" = "term-main";

      # Hyprsplit config / Hyprsplit 設定
      "plugin:hyprsplit:persistent_workspaces" = true;
      "plugin:hyprsplit:num_workspaces" = 10;

      # Environment variables / 環境変数
      env = [
        "XMODIFIERS, @im=fcitx" # Input method config / IME 設定
        "QT_QPA_PLATFORM,wayland" # Qt を Wayland へ / Force Qt to Wayland
        "QT_QPA_PLATFORMTHEME,qt5ct" # Qt theme config / Qt テーマ設定
        "QT_STYLE_OVERRIDE,Adwaita-Dark" # Qt スタイル / Qt style override
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1" # Disable Qt decorations / Qt 装飾無効
        "NIXOS_OZONE_WL,1" # Force Wayland for Chromium apps / Chromium を Wayland 化
        "ELECTRON_OZONE_PLATFORM_HINT,auto"
        # Declare window system for hints / hints 用にウィンドウシステムを明示
        "HINTS_WINDOW_SYSTEM,hyprland"
      ];

      # Input devices / 入力デバイス
      input = {
        kb_layout = "jp";
        kb_model = "";
        kb_variant = "";
        kb_options = "";
        follow_mouse = 2; # フォーカスなしでホバー / Hover-follow
        repeat_rate = 50; # リピートレート / Repeat rate
        repeat_delay = 200; # Repeat delay / リピート開始遅延
      };

      # Window appearance / ウィンドウ外観
      general = {
        gaps_in = 4; # Inner gaps / 内側余白
        gaps_out = 8; # Outer gaps / 外側余白
        border_size = 2; # Border width / 枠線幅
      };

      # Misc / その他
      misc = {
        enable_anr_dialog = false; # Disable ANR dialog / ANR ダイアログを無効化
      };

      # Disable Hyprland update news popup. / Hyprland アップデート情報ポップアップを無効化。
      ecosystem = {
        no_update_news = true;
      };

      # Window rules / ウィンドウルール
      windowrule = [ ];

      windowrulev2 = [
        "float,class:^(pavucontrol)$"
        "float,class:^(nm-connection-editor)$"
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

        # Opaque rules / 不透明ルール
        "opaque, class:(code)"
        "opaque, class:(Code)"
        "opaque, class:(thunar)"
        "opaque, class:(Thunar)"
        "opaque, class:(pavucontrol)"
        "opaque, class:(Pavucontrol)"
        "opaque, class:(org.gnome.Nautilus)"
        "opaque, class:(nemo)"
        "opaque, class:(Nemo)"
        "opaque, class:(zen)"
        "opaque, class:(firefox)"
        "opaque, class:(Firefox)"
        "float, class:^(com\\.mitchellh\\.ghostty\\.quick\\.(left|right))$"
        "workspace 99 silent,class:^(com\\.mitchellh\\.ghostty\\.quick\\.(left|right))$"
        "noshadow, class:^(com\\.mitchellh\\.ghostty\\.quick\\.(left|right))$"
        "noanim, class:^(com\\.mitchellh\\.ghostty\\.quick\\.(left|right))$"

        # Street Fighter 6 on DP-2 fullscreen. / Street Fighter 6 を DP-2 でフルスクリーン。
        "monitor DP-2, class:^(steam_app_1364780)$"
        "fullscreen, class:^(steam_app_1364780)$"

        "workspace 20 silent,class:^(discord)$"
        "workspace 2 silent,class:^(steam)$"
      ];

      # Keybindings / キーバインド
      bind = [
        # System controls / システム操作
        "$mainMod,Return,exec,$term"
        "$mainMod SHIFT,Q,killactive,"
        "$mainMod SHIFT, E, exec, ironbar-toggle-power-menu"
        "$mainMod SHIFT, F,fullscreen,"
        "$mainMod SHIFT, P, pin"
        "$mainMod,E,exec,nautilus"
        "CTRL, 4, exec,rofi -show drun"
        "CTRL SHIFT, 4, exec, term-ghostty"
        "CTRL, 1, exec,bemoji -t -c -e -n"
        "CTRL, 2, exec, hints-once"
        "$mainMod,P,pseudo,"

        # Utility controls / ユーティリティ操作
        "$mainMod SHIFT, c, exec, hyprpicker --autocopy"
        "CTRL SHIFT, Space, exec, toggle-japanese-im"

        # Window focus / フォーカス移動
        "$mainMod, j, movefocus, l"
        "$mainMod, k, movefocus, d"
        "$mainMod, l, movefocus, u"
        "$mainMod, semicolon, movefocus, r"
        "$mainMod, Tab, cyclenext"
        "$mainMod SHIFT, Tab, cyclenext, prev"

        # Window movement / ウィンドウ移動
        "$mainMod SHIFT, j, movewindow, l"
        "$mainMod SHIFT, k, movewindow, d"
        "$mainMod SHIFT, l, movewindow, u"
        "$mainMod SHIFT, semicolon, movewindow, r"

        # Monitor control / モニター制御
        "$mainMod, Tab, exec, hyprctl monitors -j|jq 'map(select(.focused|not).activeWorkspace.id)[0]'|xargs hyprctl dispatch workspace"

        # Screenshot controls / スクリーンショット操作
        '', Print, exec, grimblast save output - | swappy -f - -o /tmp/screenshot.png && zenity --question --text="Save?" && cp /tmp/screenshot.png $HOME/Pictures/$(date +%Y-%m-%dT%H:%M:%S).png''
        ''$mainMod, Print, exec, grimblast save active - | swappy -f - -o /tmp/screenshot.png && zenity --question --text="Save?" && cp /tmp/screenshot.png "$HOME/Pictures/$(date +%Y-%m-%dT%H:%M:%S).png"''
        ''CTRL, Print, exec, grim -g "$(slurp)" $HOME/Pictures/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png''
        ''SHIFT, Print, exec, grimblast copy area && notify-send "Screenshot" "領域のスクリーンショットをクリップボードにコピーしました"''
        ''CTRL SHIFT, Print, exec, grimblast copy output && notify-send "Screenshot" "画面全体のスクリーンショットをクリップボードにコピーしました"''

        # Screen recording / 画面録画
        ''$mainMod SHIFT, r, exec, wf-recorder -g "$(slurp)" -f ~/Videos/screencast_$(date +%Y-%m-%d_%H-%M-%S).mp4''
        ''$mainMod SHIFT, s, exec, killall -s SIGINT wf-recorder''

        # Volume controls / 音量調整
        ", XF86AudioLowerVolume, exec, hypr-media volume-down"
        ", XF86AudioRaiseVolume, exec, hypr-media volume-up"
        ", XF86AudioMute, exec, hypr-media volume-mute"

        # Media playback / メディア操作
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"

        # Brightness / 輝度調整
        ", XF86MonBrightnessUp, exec, hypr-media brightness-up"
        ", XF86MonBrightnessDown, exec, hypr-media brightness-down"

        # Quick terminal / クイックターミナル
        "CTRL, 3, exec, quick-term"

      ] ++ [
        "$mainMod, 0, split:workspace, 10"
        "$mainMod SHIFT, 0, split:movetoworkspace, 10"
      ] ++ (builtins.concatLists (
        builtins.genList
          (
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

      # Animations / アニメーション設定
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
        "hyprctl dispatch exec [workspace 1 silent] ${pkgs.brave}/bin/brave"
        "hyprctl dispatch exec [workspace 2 silent] term-main"
        "${pkgs.discord-ptb}/bin/discordptb"
      ];

      # Layer rules / レイヤールール
      # Disable animations for hints overlay. / hints のオーバーレイはアニメーションを無効化。
      layerrule = [
        "noanim, namespace:hints"
      ];
    };

    # Hyprland plugins / Hyprland プラグイン
    plugins = [
      hyprsplit.packages.${pkgs.system}.hyprsplit # Per-monitor workspaces / モニター別ワークスペース
    ];
  };

  # Hints UI config / Hints UI 設定
  # Shrink overlay footprint. / オーバーレイを小さく表示。
  xdg.configFile."hints/config.json" = {
    text = builtins.toJSON {
      hints = {
        hint_height = 22; # Smaller than default 30 / 既定30 から縮小
        hint_width_padding = 6; # Narrower than default 10 / 既定10 から縮小
        hint_font_size = 11; # Smaller than default 15 / 既定15 から縮小
        hint_font_face = "Noto Sans CJK JP"; # JP-friendly font / 日本語でも視認性の良いフォント
      };
      backends = { enable = [ "opencv" ]; };
      overlay_x_offset = 0;
      overlay_y_offset = -32; # Offset upward by bar height / バー分上へ
    };
  };

  # hints daemon service / hintsd サービス
  systemd.user.services.hintsd = {
    Unit = {
      Description = "Hints daemon";
      After = [ "graphical-session.target" "at-spi-dbus-bus.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.hints}/bin/hintsd";
      Restart = "on-failure";
      Environment = [ "HINTS_WINDOW_SYSTEM=hyprland" ];
    };
    Install = { WantedBy = [ "default.target" ]; };
  };

  # No client one-shot services / クライアント用 one-shot は未定義
}
