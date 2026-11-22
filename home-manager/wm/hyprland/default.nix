{ pkgs, inputs, lib, hostname, ... }:
let
  displayLayout = import ./display-layout.nix;
  quickTermMonitor = if hostname == "hq" then "desc:${displayLayout.hq.left}" else "";
  devTermMonitor = if hostname == "hq" then "desc:${displayLayout.hq.right}" else "DP-2";
  isuconLayoutMonitor = if hostname == "hq" then "desc:${displayLayout.hq.left}" else "";
  hyprlandPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;

  # Lua config helpers. Home Manager renders each settings entry as hl.<name>(...). / Lua 設定の補助。Home Manager は settings の各項目を hl.<name>(...) として出力する。
  toLua = lib.generators.toLua { };
  luaInline = lib.generators.mkLuaInline;
  mainMod = "ALT";
  term = "term-main";
  exec = command: "hl.dsp.exec_cmd(${toLua command})";
  # Bind a key combination such as "ALT + SHIFT + Q" to a dispatcher expression. / "ALT + SHIFT + Q" のようなキーの組み合わせに dispatcher の式を割り当てる。
  keyCombo = mods: key: lib.concatStringsSep " + " (mods ++ [ key ]);
  mkBind = mods: key: dispatcher: { _args = [ (keyCombo mods key) (luaInline dispatcher) ]; };
  mkMouseBind = mods: key: dispatcher: { _args = [ (keyCombo mods key) (luaInline dispatcher) { mouse = true; } ]; };
  # Single-line window rule: a name, a match table, and effects. / ウィンドウ規則 1 件。名前、照合条件、効果からなる。
  mkWindowRule = name: match: effects: { inherit name match; } // effects;

  # split-monitor-workspaces settings. On hq, order monitors by description, not connector. / split-monitor-workspaces の設定。hq ではコネクター名ではなく説明文でモニターの順を決める。
  splitWorkspacesConfig = {
    workspace_count = displayLayout.workspacesPerMonitor;
    enable_persistent_workspaces = true;
    keep_focused = true;
    monitor_priority = lib.optionals (hostname == "hq") [
      "desc:${displayLayout.hq.left}"
      "desc:${displayLayout.hq.right}"
    ];
  };
  hyprlandPipDrag = pkgs.callPackage ../../../pkgs/hyprland-pip-drag {
    hyprland = hyprlandPackage;
  };
  pipWindowState = pkgs.writeShellApplication {
    name = "pip-window-state";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./pip-window-state.py} "$@"
    '';
  };
in
{
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

    # Input & clipboard / 入力とクリップボード
    bemoji
    wl-clipboard

    # Audio & media / オーディオとメディア
    pamixer
    playerctl
    wireplumber

    # System helpers / システム補助
    wev
    polkit
    hyprpolkitagent
    libsecret
    networkmanagerapplet
    bluez
    pipWindowState
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
        preferred_monitor=${lib.escapeShellArg quickTermMonitor}
        hidden_workspace="99"
        state_file="''${XDG_RUNTIME_DIR:-/tmp}/quick-term-last-focused-$UID"
        return_state_file="''${XDG_RUNTIME_DIR:-/tmp}/quick-term-return-window-$UID"

        get_client_pid() {
          _class="$1"
          hyprctl clients -j | jq -r --arg class "$_class" 'first(.[] | select(.class == $class) | .pid) // empty'
        }

        get_active_window_addr() {
          hyprctl activewindow -j | jq -r '.address // empty'
        }

        get_active_window_class() {
          hyprctl activewindow -j | jq -r '.class // ""'
        }

        get_client_workspace() {
          _class="$1"
          hyprctl clients -j | jq -r --arg class "$_class" 'first(.[] | select(.class == $class) | .workspace.name) // empty'
        }

        get_client_pinned() {
          _class="$1"
          hyprctl clients -j | jq -r --arg class "$_class" 'first(.[] | select(.class == $class) | (.pinned | tostring)) // empty'
        }

        is_quick_term_visible_on_active_workspace() {
          _active_ws="$1"

          for _class in "$left_class" "$right_class"; do
            _pid="$(get_client_pid "$_class")"
            if [ -z "$_pid" ]; then
              continue
            fi

            _is_pinned_now="$(get_client_pinned "$_class")"
            if [ "$_is_pinned_now" = "true" ]; then
              return 0
            fi

            _ws="$(get_client_workspace "$_class")"
            if [ -n "$_active_ws" ] && [ "$_ws" = "$_active_ws" ]; then
              return 0
            fi
          done

          return 1
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

        client_exists() {
          _address="$1"

          if [ -z "$_address" ]; then
            return 1
          fi

          hyprctl clients -j | jq -e --arg address "$_address" 'any(.[]; .address == $address)' >/dev/null
        }

        remember_last_focused_quick_term() {
          _class="$1"

          if is_quick_term_class "$_class"; then
            printf '%s\n' "$_class" > "$state_file"
          fi
        }

        remember_return_window() {
          _address="$(get_active_window_addr)"
          _class="$(get_active_window_class)"

          if [ -n "$_address" ] && ! is_quick_term_class "$_class"; then
            printf '%s\n' "$_address" > "$return_state_file"
          fi
        }

        focus_return_window() {
          if [ ! -r "$return_state_file" ]; then
            return 1
          fi

          IFS= read -r _address < "$return_state_file" || return 1

          if ! client_exists "$_address"; then
            return 1
          fi

          hyprctl dispatch "hl.dsp.focus({ window = 'address:$_address' })" >/dev/null
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

        get_target_monitor() {
          if [ -n "$preferred_monitor" ]; then
            _monitor="$(
              hyprctl monitors -j | jq -r --arg monitor "$preferred_monitor" '
                first(.[] | select(.name == $monitor or ("desc:" + .description) == $monitor) | .name) // empty
              '
            )"

            if [ -z "$_monitor" ]; then
              printf 'quick-term monitor not found: %s\n' "$preferred_monitor" >&2
              return 1
            fi

            printf '%s\n' "$_monitor"
            return 0
          fi

          get_active_monitor
        }

        get_monitor_active_workspace() {
          _monitor="$1"

          hyprctl monitors -j | jq -r --arg monitor "$_monitor" '
            first(.[] | select(.name == $monitor) | (.activeWorkspace.name // (.activeWorkspace.id | tostring))) // empty
          '
        }

        get_quick_term_geometry_for_monitor() {
          _monitor="$1"
          _side="$2"

          if [ -z "$_monitor" ]; then
            return 0
          fi

          _geometry="$(
            hyprctl monitors -j | jq -r --arg monitor "$_monitor" --arg side "$_side" '
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
              append_batch_command "dispatch hl.dsp.window.pin({ action = 'enable', window = 'pid:$_pid' })"
            fi

            if [ "$_desired" = "false" ] && [ "$_is_pinned_now" = "true" ]; then
              append_batch_command "dispatch hl.dsp.window.pin({ action = 'disable', window = 'pid:$_pid' })"
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
            append_batch_command "dispatch hl.dsp.window.move({ workspace = '$_active_ws', follow = false, window = 'pid:$_pid' })"
          fi

          if [ -n "$_geometry" ]; then
            read -r _x _y _w _h <<< "$_geometry"
            append_batch_command "dispatch hl.dsp.window.resize({ x = $_w, y = $_h, window = 'pid:$_pid' })"
            append_batch_command "dispatch hl.dsp.window.move({ x = $_x, y = $_y, window = 'pid:$_pid' })"
          fi
        }

        append_quick_term_hide_commands() {
          _class="$1"
          _pid="$(get_client_pid "$_class")"

          if [ -z "$_pid" ]; then
            return 0
          fi

          append_batch_command "dispatch hl.dsp.window.move({ workspace = '$hidden_workspace', follow = false, window = 'pid:$_pid' })"
        }

        _focused_class="$(get_active_window_class)"
        _active_ws="$(hyprctl activeworkspace -j | jq -r '.name // empty')"

        if is_quick_term_visible_on_active_workspace "$_active_ws"; then
          if is_quick_term_class "$_focused_class"; then
            remember_last_focused_quick_term "$_focused_class"
            focus_return_window || true
          fi
          _batch_commands=""
          append_quick_term_pin_state_commands "false" "$right_class" "$left_class"
          append_quick_term_hide_commands "$left_class"
          append_quick_term_hide_commands "$right_class"
          if [ -n "$_batch_commands" ]; then
            hyprctl --batch "$_batch_commands" >/dev/null 2>&1
          fi
          exit 0
        fi

        remember_return_window

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

        _target_monitor="$(get_target_monitor)" || exit 1
        if [ -z "$_target_monitor" ]; then
          printf 'no monitor available for quick-term\n' >&2
          exit 1
        fi

        _target_ws="$(get_monitor_active_workspace "$_target_monitor")"
        if [ -z "$_target_ws" ]; then
          printf 'no active workspace for quick-term monitor: %s\n' "$_target_monitor" >&2
          exit 1
        fi

        _left_geometry="$(get_quick_term_geometry_for_monitor "$_target_monitor" "left")"
        _right_geometry="$(get_quick_term_geometry_for_monitor "$_target_monitor" "right")"

        _batch_commands=""
        append_quick_term_show_commands "$left_class" "$_left_geometry" "$_target_ws"
        append_quick_term_show_commands "$right_class" "$_right_geometry" "$_target_ws"
        append_quick_term_pin_state_commands "true" "$right_class" "$left_class"

        _preferred_class="$(get_preferred_quick_term_class)"
        _preferred_pid="$(get_client_pid "$_preferred_class")"
        if [ -n "$_preferred_pid" ]; then
          append_batch_command "dispatch hl.dsp.focus({ window = 'pid:$_preferred_pid' })"
          remember_last_focused_quick_term "$_preferred_class"
        else
          _alternate_class="$(get_alternate_quick_term_class "$_preferred_class")"
          _alternate_pid="$(get_client_pid "$_alternate_class")"
          if [ -n "$_alternate_pid" ]; then
            append_batch_command "dispatch hl.dsp.focus({ window = 'pid:$_alternate_pid' })"
            remember_last_focused_quick_term "$_alternate_class"
          fi
        fi

        if [ -n "$_batch_commands" ]; then
          hyprctl --batch "$_batch_commands" >/dev/null 2>&1
        fi
      '';
    })

    (pkgs.writeShellApplication {
      name = "dev-monitor-term";
      runtimeInputs = with pkgs; [
        coreutils
        ghostty
        jq
      ];
      bashOptions = [ "errexit" "nounset" "pipefail" ];
      text = ''
        dev_class="com.mitchellh.ghostty.dev.monitor"
        preferred_monitor=${lib.escapeShellArg devTermMonitor}
        workspace_number="1"
        state_file="''${XDG_RUNTIME_DIR:-/tmp}/dev-monitor-term-last-focused-$UID"

        get_active_window_addr() {
          hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' || true
        }

        get_active_window_class() {
          hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty' || true
        }

        get_dev_terminal_addr() {
          hyprctl clients -j 2>/dev/null | jq -r --arg class "$dev_class" 'first(.[] | select(.class == $class) | .address) // empty' || true
        }

        get_target_monitor() {
          _monitor="$(
            hyprctl monitors -j | jq -r --arg monitor "$preferred_monitor" '
              first(.[] | select(.name == $monitor or ("desc:" + .description) == $monitor) | .name) // empty
            '
          )"

          if [ -n "$_monitor" ]; then
            printf '%s\n' "$_monitor"
            return 0
          fi

          ${if hostname == "hq" then ''
            printf 'dev terminal monitor not found: %s\n' "$preferred_monitor" >&2
            return 1
          '' else ''
            hyprctl monitors -j | jq -r '
              first(.[] | select(.focused == true) | .name) // first(.[] | .name) // empty
            '
          ''}
        }

        get_monitor_active_workspace() {
          _monitor="$1"

          hyprctl monitors -j 2>/dev/null | jq -r --arg monitor "$_monitor" '
            first(.[] | select(.name == $monitor) | .activeWorkspace.id) // empty
          ' || true
        }

        client_exists() {
          _address="$1"

          if [ -z "$_address" ]; then
            return 1
          fi

          hyprctl clients -j 2>/dev/null | jq -e --arg address "$_address" 'any(.[]; .address == $address)' >/dev/null
        }

        remember_return_window() {
          _address="$(get_active_window_addr)"
          _class="$(get_active_window_class)"

          if [ -n "$_address" ] && [ "$_class" != "$dev_class" ]; then
            printf '%s\n' "$_address" > "$state_file"
          fi
        }

        focus_return_window() {
          if [ ! -r "$state_file" ]; then
            return 1
          fi

          IFS= read -r _address < "$state_file" || return 1

          if ! client_exists "$_address"; then
            return 1
          fi

          hyprctl dispatch "hl.dsp.focus({ window = 'address:$_address' })" >/dev/null
        }

        focus_dev_workspace() {
          _monitor="$(get_target_monitor)"

          if [ -z "$_monitor" ]; then
            printf 'no monitor available for dev terminal\n' >&2
            exit 1
          fi

          hyprctl --batch "dispatch hl.dsp.focus({ monitor = '$_monitor' }) ; dispatch smw.workspace('$workspace_number')" >/dev/null
          get_monitor_active_workspace "$_monitor"
        }

        launch_dev_terminal() {
          _workspace="$1"

          if [ -n "$_workspace" ]; then
            hyprctl dispatch "hl.dsp.exec_cmd('${pkgs.ghostty}/bin/ghostty --class=$dev_class --gtk-single-instance=false --window-padding-y=2,8 --font-size=12.5', { workspace = '$_workspace silent' })" >/dev/null
            return 0
          fi

          ${pkgs.ghostty}/bin/ghostty --class="$dev_class" --gtk-single-instance=false --window-padding-y=2,8 --font-size=12.5 >/dev/null 2>&1 &
        }

        move_dev_terminal_to_workspace() {
          _address="$1"
          _workspace="$2"

          if [ -z "$_address" ] || [ -z "$_workspace" ]; then
            return 0
          fi

          hyprctl dispatch "hl.dsp.window.move({ workspace = '$_workspace', follow = false, window = 'address:$_address' })" >/dev/null
        }

        wait_for_dev_terminal() {
          _attempt=0

          while [ "$_attempt" -lt 100 ]; do
            if [ -n "$(get_dev_terminal_addr)" ]; then
              return 0
            fi

            sleep 0.05
            _attempt=$((_attempt + 1))
          done

          return 1
        }

        focus_dev_terminal() {
          _address="$(get_dev_terminal_addr)"

          if [ -z "$_address" ]; then
            return 1
          fi

          hyprctl dispatch "hl.dsp.focus({ window = 'address:$_address' })" >/dev/null
        }

        if [ "$(get_active_window_class)" = "$dev_class" ]; then
          focus_return_window || true
          exit 0
        fi

        remember_return_window

        target_workspace="$(focus_dev_workspace)"
        dev_address="$(get_dev_terminal_addr)"

        if [ -n "$dev_address" ]; then
          move_dev_terminal_to_workspace "$dev_address" "$target_workspace"
          focus_dev_terminal
        else
          launch_dev_terminal "$target_workspace"
          wait_for_dev_terminal || true
          focus_dev_terminal
        fi
      '';
    })

    # Arrange Linear | Ghostty | Discord on workspace 3 for ISUCON. / ISUCON 用に ws 3 へ Linear | Ghostty | Discord を並べる。
    (pkgs.writeShellApplication {
      name = "isucon-layout";
      runtimeInputs = with pkgs; [
        coreutils
        jq
        libnotify
        util-linux
      ];
      bashOptions = [ "errexit" "nounset" "pipefail" ];
      text = ''
        preferred_monitor=${lib.escapeShellArg isuconLayoutMonitor}
        workspace_number="3"
        stage_workspace="special:isucon-layout"
        # Linear PWA installed in Brave. / Brave に入れた Linear の PWA。
        linear_app_id="bgdbmehlmdmddlgneophbcddadgknlpm"
        linear_class="brave-''${linear_app_id}-Default"
        term_class="com.mitchellh.ghostty"
        discord_class="vesktop"
        linear_command="${pkgs.brave}/bin/brave --profile-directory=Default --app-id=''${linear_app_id}"
        term_command="term-main"
        discord_command="${pkgs.vesktop}/bin/vesktop"
        # Dwindle gives the first child ratio / 2: Linear 25%, Ghostty 45%, Discord 30%. / dwindle は先頭の子に ratio / 2 を割り当てる。
        # Keep Discord at 30% or more because Vesktop's minimum width is 940px. / Vesktop の最小幅が 940px なので Discord は 30% 以上にする。
        root_ratio="0.5"
        right_ratio="1.2"

        # Single-instance guard / 二重実行を防ぐ
        exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/isucon-layout-$UID.lock"
        flock -n 9 || exit 0

        notify() {
          notify-send -a isucon-layout "ISUCON layout" "$1" >/dev/null 2>&1 || true
        }

        fail() {
          notify "$1"
          printf '%s\n' "$1" >&2
          exit 1
        }

        # Quote a shell string as a Lua string literal for hyprctl dispatch. / hyprctl dispatch に渡す Lua の文字列リテラルにする。
        lua_string() {
          _escaped="''${1//\\/\\\\}"
          printf "'%s'" "''${_escaped//\'/\\\'}"
        }

        get_target_monitor() {
          hyprctl monitors -j | jq -r --arg monitor "$preferred_monitor" '
            first(.[] | select(.name == $monitor or ("desc:" + .description) == $monitor) | .name)
              // first(.[] | select(.focused == true) | .name) // empty
          '
        }

        get_monitor_active_workspace() {
          hyprctl monitors -j | jq -r --arg monitor "$1" '
            first(.[] | select(.name == $monitor) | .activeWorkspace.id) // empty
          '
        }

        get_addresses_by_class() {
          hyprctl clients -j | jq -r --arg class "$1" '.[] | select(.class == $class) | .address'
        }

        get_first_address_by_class() {
          hyprctl clients -j | jq -r --arg class "$1" 'first(.[] | select(.class == $class) | .address) // empty'
        }

        get_term_on_workspace() {
          hyprctl clients -j | jq -r --arg class "$term_class" --argjson workspace "$1" '
            [.[] | select(.class == $class and .workspace.id == $workspace and .floating == false)]
            | sort_by(.focusHistoryID) | first | .address // empty
          '
        }

        wait_for_new_window() {
          _class="$1"
          _known="$2"
          _attempt=0

          while [ "$_attempt" -lt 150 ]; do
            _address="$(
              hyprctl clients -j | jq -r --arg class "$_class" --arg known "$_known" '
                ($known | split("\n")) as $known_addresses
                | first(.[] | select(.class == $class and (.address | IN($known_addresses[]) | not)) | .address) // empty
              '
            )"

            if [ -n "$_address" ]; then
              printf '%s\n' "$_address"
              return 0
            fi

            sleep 0.1
            _attempt=$((_attempt + 1))
          done

          return 1
        }

        ensure_window() {
          _class="$1"
          _command="$2"
          _address="$(get_first_address_by_class "$_class")"

          if [ -n "$_address" ]; then
            printf '%s\n' "$_address"
            return 0
          fi

          hyprctl dispatch "hl.dsp.exec_cmd($(lua_string "$_command"))" >/dev/null
          wait_for_new_window "$_class" ""
        }

        monitor="$(get_target_monitor)"
        [ -n "$monitor" ] || fail "monitor not found"

        hyprctl --batch "dispatch hl.dsp.focus({ monitor = '$monitor' }) ; dispatch smw.workspace('$workspace_number')" >/dev/null
        workspace_id="$(get_monitor_active_workspace "$monitor")"
        [ -n "$workspace_id" ] || fail "workspace not found on $monitor"

        linear_address="$(ensure_window "$linear_class" "$linear_command")" || fail "Linear window did not appear"
        discord_address="$(ensure_window "$discord_class" "$discord_command")" || fail "Discord window did not appear"

        # Reuse a terminal already on the workspace. / ws にある端末を使い回す。
        term_address="$(get_term_on_workspace "$workspace_id")"
        if [ -z "$term_address" ]; then
          known_terms="$(get_addresses_by_class "$term_class")"
          hyprctl dispatch "hl.dsp.exec_cmd($(lua_string "$term_command"))" >/dev/null
          term_address="$(wait_for_new_window "$term_class" "$known_terms")" || fail "Ghostty window did not appear"
        fi

        # Move other tiled windows to the next workspace. / 他のタイル窓は隣の ws へ移す。
        extra_addresses="$(
          hyprctl clients -j | jq -r --argjson workspace "$workspace_id" \
            --arg linear "$linear_address" --arg term "$term_address" --arg discord "$discord_address" '
            .[] | select(.workspace.id == $workspace and .floating == false
              and .address != $linear and .address != $term and .address != $discord) | .address
          '
        )"
        extra_workspace=$((workspace_id + 1))

        batch=""
        append() {
          batch="''${batch:+$batch ; }dispatch $1"
        }
        move_silent() {
          append "hl.dsp.window.move({ workspace = '$1', follow = false, window = 'address:$2' })"
        }
        focus_window() {
          append "hl.dsp.focus({ window = 'address:$1' })"
        }

        for address in "$linear_address" "$term_address" "$discord_address"; do
          append "hl.dsp.window.float({ action = 'disable', window = 'address:$address' })"
          move_silent "$stage_workspace" "$address"
        done

        extra_count=0
        while IFS= read -r address; do
          [ -n "$address" ] || continue
          move_silent "$extra_workspace" "$address"
          extra_count=$((extra_count + 1))
        done <<< "$extra_addresses"

        # Insert from left to right; preselect opens each window right of the focused one. / 左から順に入れ、preselect でフォーカス窓の右に開く。
        move_silent "$workspace_id" "$linear_address"
        focus_window "$linear_address"
        append "hl.dsp.layout('preselect r')"
        move_silent "$workspace_id" "$term_address"
        focus_window "$term_address"
        append "hl.dsp.layout('preselect r')"
        move_silent "$workspace_id" "$discord_address"
        focus_window "$linear_address"
        # The dwindle layout message takes the value before "exact". / dwindle のレイアウトメッセージは値を exact より前に書く。
        append "hl.dsp.layout('splitratio $root_ratio exact')"
        focus_window "$term_address"
        append "hl.dsp.layout('splitratio $right_ratio exact')"

        hyprctl --batch "$batch" >/dev/null

        if [ "$extra_count" -gt 0 ]; then
          notify "Moved $extra_count other window(s) to workspace $extra_workspace"
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
    # Hyprland 0.57 reads only Lua; it removed the hyprlang reader. / Hyprland 0.57 は Lua の設定だけを読む。hyprlang の読み込みは削除された。
    configType = "lua";

    package = null;

    systemd.enable = true;
    systemd.enableXdgAutostart = true;

    # Home Manager renders settings in name order. Emit curves first so animations can name them. / Home Manager は settings を名前順に出力する。アニメーションが参照できるよう曲線を先に出す。
    importantPrefixes = [ "env" "curve" ];

    # Load before settings because the workspace binds call smw.*. Keep it global so hyprctl dispatch can reach it. / ワークスペースのバインドが smw.* を呼ぶので settings より先に読み込む。hyprctl dispatch から使えるようグローバルにする。
    extraLuaFiles.split-workspaces = ''
      smw = require("plugins.split-monitor-workspaces")
      smw.setup(${toLua splitWorkspacesConfig})
    '';

    settings = {
      config = {
        xwayland = {
          use_nearest_neighbor = false;
          force_zero_scaling = true;
        };

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

        animations = {
          enabled = true;
        };
      };

      # Environment variables / 環境変数
      env = map (pair: { _args = pair; }) [
        [ "XMODIFIERS" "@im=fcitx" ] # Input method config / IME 設定
        [ "QT_QPA_PLATFORM" "wayland" ] # Qt を Wayland へ / Force Qt to Wayland
        [ "QT_QPA_PLATFORMTHEME" "qt5ct" ] # Qt theme config / Qt テーマ設定
        [ "QT_STYLE_OVERRIDE" "Adwaita-Dark" ] # Qt スタイル / Qt style override
        [ "QT_WAYLAND_DISABLE_WINDOWDECORATION" "1" ] # Disable Qt decorations / Qt 装飾無効
        [ "NIXOS_OZONE_WL" "1" ] # Force Wayland for Chromium apps / Chromium を Wayland 化
        [ "ELECTRON_OZONE_PLATFORM_HINT" "auto" ]
        # Declare window system for hints / hints 用にウィンドウシステムを明示
        [ "HINTS_WINDOW_SYSTEM" "hyprland" ]
      ];

      # Animations / アニメーション設定
      curve = [
        { _args = [ "myBezier" { type = "bezier"; points = [ [ 0.05 0.9 ] [ 0.1 1.05 ] ]; } ]; }
      ];
      animation = [
        { leaf = "windows"; enabled = true; speed = 7; bezier = "myBezier"; }
        { leaf = "windowsOut"; enabled = true; speed = 7; bezier = "default"; style = "popin 80%"; }
        { leaf = "workspaces"; enabled = true; speed = 6; bezier = "default"; }
      ];

      # Window rules. Rules match the whole class or title. / ウィンドウルール。クラスやタイトルの全体に一致させる。
      window_rule = [
        (mkWindowRule "float-utilities"
          { class = "^(pavucontrol|nm-connection-editor|blueman-manager|xdg-desktop-portal-gtk|xdg-desktop-portal-kde|xdg-desktop-portal-hyprland|zenity)$"; }
          { float = true; })
        (mkWindowRule "float-pin-browser-pip"
          { class = "^()$"; title = "^(Picture in picture|ピクチャー イン ピクチャー)$"; }
          { float = true; pin = true; })
        (mkWindowRule "float-brave-file-dialogs"
          { class = "^(brave)$"; title = "^(Save File|Open File)$"; }
          { float = true; })
        (mkWindowRule "float-untitled-tools"
          { class = "^()$"; title = "^(Steam - Self Updater|Playwright Inspector)$"; }
          { float = true; })

        # Opaque rules / 不透明ルール
        (mkWindowRule "opaque-apps"
          { class = "(code|Code|thunar|Thunar|pavucontrol|Pavucontrol|org.gnome.Nautilus|nemo|Nemo|zen)"; }
          { opaque = true; })
        (mkWindowRule "quick-term"
          { class = "^(com\\.mitchellh\\.ghostty\\.quick\\.(left|right))$"; }
          { float = true; no_shadow = true; no_anim = true; })

        # Street Fighter 6 fullscreen. / Street Fighter 6 をフルスクリーン表示。
        (mkWindowRule "street-fighter-6-fullscreen" { class = "^(steam_app_1364780)$"; } { fullscreen = true; })
      ] ++ lib.optionals (hostname != "hq") [
        (mkWindowRule "street-fighter-6-monitor" { class = "^(steam_app_1364780)$"; } { monitor = "DP-2"; })
        (mkWindowRule "steam-workspace" { class = "^(steam)$"; } { workspace = "2 silent"; })
      ];

      # Layer rules / レイヤールール
      # Disable animations for hints overlay. / hints のオーバーレイはアニメーションを無効化。
      layer_rule = [
        { name = "hints-no-anim"; match = { namespace = "hints"; }; no_anim = true; }
      ];

      # Keybindings / キーバインド
      bind = [
        # System controls / システム操作
        (mkBind [ mainMod ] "Return" (exec term))
        (mkBind [ mainMod "SHIFT" ] "Q" "hl.dsp.window.close()")
        (mkBind [ mainMod "SHIFT" ] "E" (exec "ironbar-toggle-power-menu"))
        (mkBind [ mainMod "SHIFT" ] "F" "hl.dsp.window.fullscreen()")
        (mkBind [ mainMod "SHIFT" ] "P" "hl.dsp.window.pin()")
        (mkBind [ mainMod ] "E" (exec "nautilus"))
        (mkBind [ "CTRL" ] "4" (exec "rofi -show drun"))
        (mkBind [ "CTRL" "SHIFT" ] "4" (exec "term-ghostty"))
        (mkBind [ "CTRL" ] "1" (exec "dev-monitor-term"))
        (mkBind [ "CTRL" ] "2" (exec "hints-once"))
        (mkBind [ mainMod ] "P" "hl.dsp.window.pseudo()")
        (mkBind [ "CTRL" ] "5" (exec "bemoji -t -c -e -n"))

        # Utility controls / ユーティリティ操作
        (mkBind [ mainMod "SHIFT" ] "c" (exec "hyprpicker --autocopy"))
        (mkBind [ "CTRL" "SHIFT" ] "Space" (exec "toggle-japanese-im"))

        # Window focus / フォーカス移動
        (mkBind [ mainMod ] "j" ''hl.dsp.focus({ direction = "left" })'')
        (mkBind [ mainMod ] "k" ''hl.dsp.focus({ direction = "down" })'')
        (mkBind [ mainMod ] "l" ''hl.dsp.focus({ direction = "up" })'')
        (mkBind [ mainMod ] "semicolon" ''hl.dsp.focus({ direction = "right" })'')
        (mkBind [ mainMod ] "Tab" "hl.dsp.window.cycle_next()")
        (mkBind [ mainMod "SHIFT" ] "Tab" "hl.dsp.window.cycle_next({ next = false })")

        # Window movement / ウィンドウ移動
        (mkBind [ mainMod "SHIFT" ] "j" ''hl.dsp.window.move({ direction = "left" })'')
        (mkBind [ mainMod "SHIFT" ] "k" ''hl.dsp.window.move({ direction = "down" })'')
        (mkBind [ mainMod "SHIFT" ] "l" ''hl.dsp.window.move({ direction = "up" })'')
        (mkBind [ mainMod "SHIFT" ] "semicolon" ''hl.dsp.window.move({ direction = "right" })'')

        # Window layout / ウィンドウレイアウト
        (mkBind [ mainMod "CTRL" ] "k" ''hl.dsp.layout("preselect d")'')
        (mkBind [ mainMod "SHIFT" ] "I" (exec "isucon-layout"))

        # Screenshot controls / スクリーンショット操作
        (mkBind [ ] "Print" (exec ''grimblast save output - | swappy -f - -o /tmp/screenshot.png && zenity --question --text="Save?" && cp /tmp/screenshot.png $HOME/Pictures/$(date +%Y-%m-%dT%H:%M:%S).png''))
        (mkBind [ mainMod ] "Print" (exec ''grimblast save active - | swappy -f - -o /tmp/screenshot.png && zenity --question --text="Save?" && cp /tmp/screenshot.png "$HOME/Pictures/$(date +%Y-%m-%dT%H:%M:%S).png"''))
        (mkBind [ mainMod "SHIFT" ] "Print" (exec ''grimblast save area - | swappy -f - -o /tmp/screenshot.png && zenity --question --text="Save?" && cp /tmp/screenshot.png "$HOME/Pictures/$(date +%Y-%m-%dT%H:%M:%S).png"''))
        (mkBind [ "CTRL" ] "Print" (exec ''grim -g "$(slurp)" $HOME/Pictures/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png''))
        (mkBind [ "SHIFT" ] "Print" (exec ''grimblast copy area && notify-send "Screenshot" "領域のスクリーンショットをクリップボードにコピーしました"''))
        (mkBind [ "CTRL" "SHIFT" ] "Print" (exec ''grimblast copy output && notify-send "Screenshot" "画面全体のスクリーンショットをクリップボードにコピーしました"''))

        # Volume controls / 音量調整
        (mkBind [ ] "XF86AudioLowerVolume" (exec "hypr-media volume-down"))
        (mkBind [ ] "XF86AudioRaiseVolume" (exec "hypr-media volume-up"))
        (mkBind [ ] "XF86AudioMute" (exec "hypr-media volume-mute"))

        # Media playback / メディア操作
        (mkBind [ ] "XF86AudioPlay" (exec "playerctl play-pause"))
        (mkBind [ ] "XF86AudioNext" (exec "playerctl next"))
        (mkBind [ ] "XF86AudioPrev" (exec "playerctl previous"))

        # Brightness / 輝度調整
        (mkBind [ ] "XF86MonBrightnessUp" (exec "hypr-media brightness-up"))
        (mkBind [ ] "XF86MonBrightnessDown" (exec "hypr-media brightness-down"))

        # Quick terminal / クイックターミナル
        (mkBind [ "CTRL" ] "3" (exec "quick-term"))

        # Mouse window controls. / マウスによるウィンドウ操作。
        (mkMouseBind [ mainMod ] "mouse:272" "hl.dsp.window.drag()")
        (mkMouseBind [ mainMod ] "mouse:273" "hl.dsp.window.resize()")
      ] ++ builtins.concatLists (map
        (slot:
          let
            # Key 0 selects workspace 10. / キー 0 はワークスペース 10。
            key = builtins.toString (lib.mod slot 10);
            workspace = toLua (builtins.toString slot);
          in
          [
            (mkBind [ mainMod ] key "smw.workspace(${workspace})")
            (mkBind [ mainMod "SHIFT" ] key "smw.move_to_workspace(${workspace})")
          ])
        (lib.range 1 displayLayout.workspacesPerMonitor));
    };

    # Start apps after Home Manager's startup hook imports the session environment. / Home Manager の起動フックがセッションの環境を取り込んだ後に、アプリを起動する。
    extraConfig = ''
      hl.on("hyprland.start", function()
        hl.exec_cmd(${toLua "${pkgs.brave}/bin/brave"}, { workspace = "1 silent" })
        hl.exec_cmd(${toLua term}, { workspace = "2 silent" })
        hl.exec_cmd(${toLua "${pkgs.vesktop}/bin/vesktop"}, { workspace = "20 silent" })
      end)
    '';

    # Hyprland plugins / Hyprland プラグイン
    plugins = [
      hyprlandPipDrag # Move and aspect-ratio resize browser PiP. / ブラウザPiPを移動し、比率を保ってリサイズ。
    ];
  };

  # split-monitor-workspaces Lua package, required as plugins.split-monitor-workspaces. / split-monitor-workspaces の Lua パッケージ。plugins.split-monitor-workspaces として require する。
  xdg.configFile."hypr/plugins/split-monitor-workspaces".source = inputs.split-monitor-workspaces;

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
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };

  # Persist browser PiP position and width. / ブラウザ PiP の位置と横幅を永続化。
  systemd.user.services.pip-window-state = {
    Unit = {
      Description = "Persist Hyprland browser PiP position and width";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pipWindowState}/bin/pip-window-state daemon";
      Restart = "on-failure";
      RestartSec = 2;
      Environment = [ "PIP_WINDOW_STATE_HYPRCTL=/run/current-system/sw/bin/hyprctl" ];
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };

  # No client one-shot services / クライアント用 one-shot は未定義
}
