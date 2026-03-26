{ config, lib, pkgs, hostname, ... }:
let
  codexIcon = pkgs.writeText "ironbar-codex-icon.svg" ''
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      fill="none"
      viewBox="0 0 24 24"
    >
      <path
        d="M13.795 23.856q-1.188 0-2.256-.448a6.1 6.1 0 0 1-1.9-1.247 5.8 5.8 0 0 1-1.875.306 5.8 5.8 0 0 1-2.944-.777 6.1 6.1 0 0 1-2.184-2.12q-.807-1.34-.808-2.99 0-.682.19-1.482a6.3 6.3 0 0 1-1.472-2.002 5.76 5.76 0 0 1 .024-4.85q.546-1.177 1.52-2.024a5.5 5.5 0 0 1 2.303-1.2A5.55 5.55 0 0 1 5.485 2.62 6.06 6.06 0 0 1 7.575.925 5.85 5.85 0 0 1 10.21.313q1.187 0 2.255.447a6.1 6.1 0 0 1 1.9 1.248 5.8 5.8 0 0 1 1.875-.306q1.59 0 2.944.776a5.9 5.9 0 0 1 2.16 2.12q.832 1.34.832 2.99 0 .682-.19 1.483a6.2 6.2 0 0 1 1.472 2.024q.522 1.13.522 2.378 0 1.272-.546 2.449a6.1 6.1 0 0 1-1.543 2.048 5.45 5.45 0 0 1-2.28 1.177 5.4 5.4 0 0 1-1.115 2.402 5.8 5.8 0 0 1-2.066 1.695 5.85 5.85 0 0 1-2.635.612M7.93 20.913q1.188 0 2.066-.495l4.463-2.542a.52.52 0 0 0 .238-.448v-2.024L8.95 18.676a.97.97 0 0 1-1.044 0L3.419 16.11a.7.7 0 0 1-.024.165v.282q0 1.201.57 2.213.594.99 1.639 1.554 1.044.59 2.326.589m.238-3.838q.143.07.26.07a.46.46 0 0 0 .238-.07l1.781-1.012-5.722-3.296q-.522-.306-.522-.918v-5.11a4.27 4.27 0 0 0-1.9 1.602 4.13 4.13 0 0 0-.712 2.354q0 1.155.594 2.213.593 1.06 1.543 1.601zm5.627 5.227q1.258 0 2.279-.565a4.25 4.25 0 0 0 1.614-1.554q.594-.99.594-2.213v-5.085q0-.283-.237-.424l-1.805-1.036v6.568q0 .613-.522.919l-4.487 2.566q1.163.825 2.564.824m.902-8.617v-3.202l-2.683-1.507-2.707 1.507v3.202l2.707 1.507zm-6.933-7.51q0-.612.522-.918l4.488-2.567a4.34 4.34 0 0 0-2.564-.824q-1.26 0-2.28.565a4.25 4.25 0 0 0-1.614 1.554q-.57.99-.57 2.213v5.062q0 .283.237.447l1.781 1.036zm12.061 11.253a4.13 4.13 0 0 0 1.876-1.6 4.2 4.2 0 0 0 .712-2.355q0-1.154-.593-2.213-.594-1.06-1.544-1.6l-4.44-2.543q-.142-.095-.26-.071a.46.46 0 0 0-.238.07l-1.78.99 5.745 3.319q.26.141.38.377a.9.9 0 0 1 .142.518zm-4.772-11.96q.522-.33 1.045 0l4.51 2.614v-.424q0-1.13-.57-2.142a4.1 4.1 0 0 0-1.59-1.648q-1.02-.613-2.374-.613-1.187 0-2.066.495L9.545 6.292a.52.52 0 0 0-.238.448v2.025z"
        fill="#cad3f5"
      />
    </svg>
  '';
  claudeIcon = pkgs.fetchurl {
    url = "https://cdn.prod.website-files.com/6889473510b50328dbb70ae6/689f4a9aff1f63fde75cf733_favicon.png";
    hash = "sha256-zn6Mr+J2xNaCA4dlLXdDd3L7Lvp1Eb/5Kk52ZM0r7lE=";
  };
  hasBattery =
    let
      powerSupplyPath = "/sys/class/power_supply";
      batteryHosts = [ "laptop" ];
      sysfsBatteryCheck = builtins.tryEval (
        if builtins.pathExists powerSupplyPath then
          let
            entries = builtins.attrNames (builtins.readDir powerSupplyPath);
            batteryEntries = builtins.filter (name: builtins.match "^BAT" name != null) entries;
          in
          batteryEntries != [ ]
        else
          false
      );
      sysfsHasBattery =
        if sysfsBatteryCheck.success then sysfsBatteryCheck.value else false;
    in
    builtins.elem hostname batteryHosts || sysfsHasBattery;

  ironbarBin = lib.getExe pkgs.ironbar;
  systemctlBin = "${pkgs.systemd}/bin/systemctl";
  hyprctlBin = "hyprctl";
  cpuUsageScript = lib.getExe (pkgs.writeShellApplication {
    name = "ironbar-cpu-usage";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
    ];
    text = ''
      read -r _ _user1 _nice1 _system1 _idle1 _iowait1 _irq1 _softirq1 _steal1 _guest1 _guestnice1 < /proc/stat
      total1=$((_user1 + _nice1 + _system1 + _idle1 + _iowait1 + _irq1 + _softirq1 + _steal1 + _guest1 + _guestnice1))
      idle_total1=$((_idle1 + _iowait1))

      sleep 0.2

      read -r _ _user2 _nice2 _system2 _idle2 _iowait2 _irq2 _softirq2 _steal2 _guest2 _guestnice2 < /proc/stat
      total2=$((_user2 + _nice2 + _system2 + _idle2 + _iowait2 + _irq2 + _softirq2 + _steal2 + _guest2 + _guestnice2))
      idle_total2=$((_idle2 + _iowait2))

      total_delta=$((total2 - total1))
      idle_delta=$((idle_total2 - idle_total1))

      if [ "$total_delta" -le 0 ]; then
        cpu_percent=0
      else
        cpu_percent=$((((100 * (total_delta - idle_delta)) + (total_delta / 2)) / total_delta))
      fi

      if [ "$cpu_percent" -ge 90 ]; then
        printf '<span foreground="#ed8796">%s%%</span>\n' "$cpu_percent"
      elif [ "$cpu_percent" -ge 80 ]; then
        printf '<span foreground="#f5a97f">%s%%</span>\n' "$cpu_percent"
      else
        printf '%s%%\n' "$cpu_percent"
      fi
    '';
  });
  memoryUsageScript = lib.getExe (pkgs.writeShellApplication {
    name = "ironbar-memory-usage";
    runtimeInputs = [
      pkgs.gawk
      pkgs.procps
    ];
    text = ''
      memory_percent="$(free | awk '/^Mem:/ { printf "%.0f\n", ($3 / $2) * 100 }')"

      case "$memory_percent" in
        ""|*[!0-9]*)
          printf '--\n'
          exit 0
          ;;
      esac

      if [ "$memory_percent" -ge 90 ]; then
        printf '<span foreground="#ed8796">%s%%</span>\n' "$memory_percent"
      elif [ "$memory_percent" -ge 80 ]; then
        printf '<span foreground="#f5a97f">%s%%</span>\n' "$memory_percent"
      else
        printf '%s%%\n' "$memory_percent"
      fi
    '';
  });
  diskUsagePreferredMount = "/";
  diskUsageScript = lib.getExe (pkgs.writeShellApplication {
    name = "ironbar-disk-usage";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      preferred_target="${diskUsagePreferredMount}"
      target_path="/"

      if [ "$preferred_target" = "/" ] || findmnt -rn -M "$preferred_target" >/dev/null 2>&1; then
        target_path="$preferred_target"
      fi

      usage="$(df --output=pcent "$target_path" | tail -n +2 | tr -dc '0-9')"

      case "$usage" in
        ""|*[!0-9]*)
          printf '--\n'
          exit 0
          ;;
      esac

      if [ "$usage" -ge 90 ]; then
        printf '<span foreground="#ed8796">%s%%</span>\n' "$usage"
      elif [ "$usage" -ge 80 ]; then
        printf '<span foreground="#f5a97f">%s%%</span>\n' "$usage"
      else
        printf '%s%%\n' "$usage"
      fi
    '';
  });
  mkValueModule =
    { name
    , icon
    , script
    , interval
    ,
    }: {
      type = "custom";
      inherit name;
      class = "value-module";
      bar = [
        {
          type = "box";
          name = "${name}-box";
          class = "value-module-box";
          widgets = [
            {
              type = "label";
              name = "${name}-icon";
              class = "value-module-icon";
              label = icon;
            }
            {
              type = "label";
              name = "${name}-value";
              class = "value-module-value";
              label = "{{${builtins.toString interval}:${script}}}";
            }
          ];
        }
      ];
    };
  mkProcessCountScript = name: matchNames:
    lib.getExe (pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gawk
        pkgs.procps
      ];
      text = ''
        current_user="$(id -un)"

        ps -u "$current_user" -o comm= | awk '
          BEGIN {
            split("${lib.concatStringsSep " " matchNames}", names, " ")
            for (i in names) {
              watched[names[i]] = 1
            }
          }

          watched[$1] {
            count += 1
          }

          END {
            printf "%d\n", count + 0
          }
        '
      '';
    });
  codexProcessCountScript = mkProcessCountScript "ironbar-codex-process-count" [
    ".codex-real"
    "codex"
  ];
  claudeProcessCountScript = mkProcessCountScript "ironbar-claude-process-count" [
    ".claude-real"
    "claude"
  ];
  aiProcessesModule = {
    type = "custom";
    name = "ai-processes";
    class = "ai-processes";
    bar = [
      {
        type = "box";
        name = "ai-processes-box";
        class = "ai-processes-box";
        widgets = [
          {
            type = "box";
            name = "codex-process";
            class = "ai-process";
            widgets = [
              {
                type = "image";
                name = "codex-icon";
                src = "file://${codexIcon}";
                size = 8;
              }
              {
                type = "label";
                name = "codex-count";
                class = "ai-process-count";
                label = "{{3000:${codexProcessCountScript}}}";
              }
            ];
          }
          {
            type = "box";
            name = "claude-process";
            class = "ai-process";
            widgets = [
              {
                type = "image";
                name = "claude-icon";
                src = "file://${claudeIcon}";
                size = 16;
              }
              {
                type = "label";
                name = "claude-count";
                class = "ai-process-count";
                label = "{{3000:${claudeProcessCountScript}}}";
              }
            ];
          }
        ];
      }
    ];
  };

  workspaceDigits = map builtins.toString (lib.range 1 9) ++ [ "0" ];
  workspaceDisplayDigit =
    workspace:
    if workspace <= 10 then
      builtins.elemAt workspaceDigits (workspace - 1)
    else
      builtins.elemAt workspaceDigits (workspace - 11);
  workspaceSuffixVar = workspace: "workspace_${builtins.toString workspace}_suffix";
  mkWorkspaceModule = workspace: {
    type = "custom";
    name = "workspace-${builtins.toString workspace}";
    class = "workspace-pill";
    bar = [
      {
        type = "button";
        class = "workspace-button";
        justify = "center";
        on_click = "!${hyprctlBin} dispatch workspace ${builtins.toString workspace}";
        label = "<span weight=\"800\">${workspaceDisplayDigit workspace}</span>\n<span size=\"smaller\">#${workspaceSuffixVar workspace}</span>";
      }
    ];
  };
  primaryWorkspaceModules = map mkWorkspaceModule (lib.range 1 10);
  secondaryWorkspaceModules = map (index: mkWorkspaceModule (index + 10)) (lib.range 1 10);

  mkFocused = maxLength: {
    type = "focused";
    name = "focused-window";
    icon_size = 18;
    justify = "center";
    show_icon = true;
    show_title = true;
    truncate = {
      mode = "end";
      max_length = maxLength;
    };
  };

  musicModule = {
    type = "music";
    name = "music";
    player_type = "mpris";
    format = "{title}";
    show_status_icon = true;
    truncate = {
      mode = "end";
      max_length = 34;
    };
    icons = {
      play = "";
      pause = "";
      prev = "󰒮";
      next = "󰒭";
      volume = "󰕾";
      track = "󰎈";
      album = "󰀥";
      artist = "󰠃";
    };
  };

  cpuModule = mkValueModule {
    name = "cpu";
    icon = "";
    script = cpuUsageScript;
    interval = 1000;
  };
  memoryModule = mkValueModule {
    name = "memory";
    icon = "󰍛";
    script = memoryUsageScript;
    interval = 5000;
  };
  diskModule = mkValueModule {
    name = "disk";
    icon = "󰋊";
    script = diskUsageScript;
    interval = 30000;
  };

  volumeModule = {
    type = "volume";
    name = "volume";
    format = "{icon} {percentage}%";
    max_volume = 100;
    truncate = "middle";
    icons = {
      volume_high = "󰕾";
      volume_medium = "󰖀";
      volume_low = "󰕿";
      muted = "󰝟";
      mic_volume = "";
      mic_muted = "";
    };
    on_click_right = "${pkgs.pavucontrol}/bin/pavucontrol";
  };

  networkModule = {
    type = "network_manager";
    name = "network";
    icon_size = 18;
    types_blacklist = [
      "loopback"
      "bridge"
    ];
  };

  bluetoothModule = {
    type = "bluetooth";
    name = "bluetooth";
    icon_size = 18;
    format = {
      not_found = "";
      disabled = "󰂲";
      enabled = "󰂯";
      connected = "󰂱 {device_alias}";
      connected_battery = "󰂱 {device_alias} {device_battery_percent}%";
    };
    popup = {
      max_height = {
        devices = 6;
      };
      header = "Bluetooth";
    };
  };

  batteryModule = {
    type = "battery";
    name = "battery";
    format = "{percentage}%";
    show_icon = true;
    show_label = true;
    thresholds = {
      warning = 25;
      critical = 10;
    };
  };

  notificationsModule = {
    type = "notifications";
    name = "notifications";
    show_count = false;
    icons = {
      closed_none = "󰍥";
      closed_some = "󱥂";
      closed_dnd = "󱅯";
      open_none = "󰍡";
      open_some = "󱥁";
      open_dnd = "󱅮";
    };
  };

  trayModule = {
    type = "tray";
    name = "tray";
    icon_size = 18;
    prefer_theme_icons = true;
  };

  clockModule = {
    type = "clock";
    name = "clock";
    format = "%Y/%m/%d %H:%M";
    format_popup = "%H:%M:%S";
    locale = "ja_JP";
  };

  powerMenuModule = {
    type = "custom";
    name = "power-menu";
    class = "power-menu";
    tooltip = "Session controls";
    bar = [
      {
        type = "button";
        name = "power-trigger";
        label = "";
        on_click = "popup:toggle";
      }
    ];
    popup = [
      {
        type = "box";
        name = "power-popup";
        orientation = "vertical";
        widgets = [
          {
            type = "label";
            name = "power-heading";
            label = "Session";
          }
          {
            type = "box";
            class = "power-actions";
            widgets = [
              {
                type = "button";
                class = "power-action";
                label = "<span font-size='18pt'>󰤄</span>";
                on_click = "!${systemctlBin} suspend";
              }
              {
                type = "button";
                class = "power-action";
                label = "<span font-size='18pt'>󰜉</span>";
                on_click = "!${hyprctlBin} dispatch exit";
              }
              {
                type = "button";
                class = "power-action";
                label = "<span font-size='18pt'></span>";
                on_click = "!${systemctlBin} reboot";
              }
              {
                type = "button";
                class = "power-action";
                label = "<span font-size='18pt'></span>";
                on_click = "!${systemctlBin} poweroff";
              }
            ];
          }
          {
            type = "label";
            name = "power-uptime";
            label = "Up {{30000:uptime -p | cut -d ' ' -f2-}}";
          }
        ];
      }
    ];
  };

  barDefaults = {
    anchor_to_edges = true;
    exclusive_zone = true;
    icon_theme = "Papirus";
    layer = "top";
    popup_gap = 10;
    position = "top";
  };

  desktopStart = primaryWorkspaceModules;
  compactStart = primaryWorkspaceModules;
  desktopStartSecondary = secondaryWorkspaceModules;
  desktopCenter = [ (mkFocused 42) ];
  compactCenter = [ (mkFocused 18) ];

  workspaceStateScript = lib.getExe (pkgs.writeShellApplication {
    name = "ironbar-workspace-state";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.ironbar
      pkgs.jq
      pkgs.socat
    ];
    text = ''
      set -eu

      export PATH="/run/current-system/sw/bin:$HOME/.nix-profile/bin:$PATH"

      declare -A last_vars=()
      declare -A last_classes=()

      wait_for_ironbar() {
        until ironbar ping >/dev/null 2>&1; do
          sleep 1
        done
      }

      find_hypr_socket() {
        local runtime_dir signature candidate best best_mtime mtime

        runtime_dir="''${XDG_RUNTIME_DIR-}"
        signature="''${HYPRLAND_INSTANCE_SIGNATURE-}"
        if [ -z "$runtime_dir" ]; then
          runtime_dir="/run/user/$UID"
        fi

        best=""
        best_mtime=0

        if [ -n "$signature" ]; then
          candidate="$runtime_dir/hypr/$signature/.socket2.sock"
          if [ -S "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
          fi
        fi

        for candidate in "$runtime_dir"/hypr/*/.socket2.sock; do
          [ -S "$candidate" ] || continue

          mtime="$(stat -c '%Y' "$candidate" 2>/dev/null || printf '0')"
          if [ "$mtime" -ge "$best_mtime" ]; then
            best="$candidate"
            best_mtime="$mtime"
          fi
        done

        [ -n "$best" ] || return 1
        printf '%s\n' "$best"
      }

      set_var_if_changed() {
        local key value current

        key="$1"
        value="$2"
        current="__missing__"
        if [ -v "last_vars[$key]" ]; then
          current="''${last_vars[$key]}"
        fi

        [ "$current" = "$value" ] && return 0

        if ironbar var set "$key" "$value" >/dev/null 2>&1; then
          last_vars["$key"]="$value"
          return 0
        fi

        return 1
      }

      set_class_if_changed() {
        local module_name class_name desired key current

        module_name="$1"
        class_name="$2"
        desired="$3"
        key="$module_name:$class_name"
        current="__missing__"
        if [ -v "last_classes[$key]" ]; then
          current="''${last_classes[$key]}"
        fi

        [ "$current" = "$desired" ] && return 0

        if [ "$desired" = "1" ]; then
          if ironbar style add-class "$module_name" "$class_name" >/dev/null 2>&1; then
            last_classes["$key"]="$desired"
            return 0
          fi
        else
          if ironbar style remove-class "$module_name" "$class_name" >/dev/null 2>&1; then
            last_classes["$key"]="$desired"
            return 0
          fi
        fi

        return 1
      }

      build_suffix() {
        local app_count has_brave dot_count suffix

        app_count="$1"
        has_brave="$2"

        if [ "$app_count" -le 0 ]; then
          printf '%s' ""
          return 0
        fi

        dot_count="$app_count"
        if [ "$dot_count" -gt 3 ]; then
          dot_count=3
        fi

        case "$dot_count:$has_brave" in
          1:0)
            suffix="•"
            ;;
          1:1)
            suffix="<span foreground=\"#f5a97f\">•</span>"
            ;;
          2:0)
            suffix="••"
            ;;
          2:1)
            suffix="<span foreground=\"#f5a97f\">•</span>•"
            ;;
          3:0)
            suffix="•••"
            ;;
          3:1)
            suffix="<span foreground=\"#f5a97f\">•</span>••"
            ;;
          *)
            suffix=""
            ;;
        esac

        printf '%s' "$suffix"
      }

      should_refresh_for_event() {
        local event_name

        event_name="$1"
        case "$event_name" in
          workspace*|focusedmon*|movewindow*|openwindow*|closewindow*|createworkspace*|destroyworkspace*|renameworkspace*)
            return 0
            ;;
          *)
            return 1
            ;;
        esac
      }

      update_state() {
        local clients_json focused_json rows ws count has_brave focused suffix module_name

        clients_json="$(hyprctl clients -j 2>/dev/null)" || return 1
        focused_json="$(hyprctl activeworkspace -j 2>/dev/null)" || return 1

        rows="$(
          jq -nr \
            --argjson clients "$clients_json" \
            --argjson focused "$focused_json" \
            '
              def app_id: (.class // .initialClass // .title // .address // "unknown") | ascii_downcase;
              def is_brave: ((.class // .initialClass // "") | ascii_downcase | contains("brave"));
              def stats:
                reduce ($clients[] | select(.workspace.id >= 1 and .workspace.id <= 20)) as $client
                  ({};
                    .[($client.workspace.id | tostring)] = (
                      (.[($client.workspace.id | tostring)] // { apps: [], brave: false })
                      | .apps += [($client | app_id)]
                      | .brave = (.brave or ($client | is_brave))
                    )
                  );
              (stats) as $stats
              | (($focused.id // -1)) as $focused
              | range(1; 21)
              | . as $ws
              | ($stats[($ws | tostring)] // { apps: [], brave: false }) as $state
              | [
                  $ws,
                  ($state.apps | unique | length),
                  (if $state.brave then 1 else 0 end),
                  (if $focused == $ws then 1 else 0 end)
                ]
              | @tsv
            '
        )" || return 1

        while IFS=$'\t' read -r ws count has_brave focused; do
          [ -n "$ws" ] || continue

          suffix="$(build_suffix "$count" "$has_brave")" || return 1
          set_var_if_changed "workspace_''${ws}_suffix" "$suffix" || return 1

          module_name="workspace-$ws"
          set_class_if_changed "$module_name" "focused" "$focused" || return 1
        done <<< "$rows"
      }

      while true; do
        if ! command -v hyprctl >/dev/null 2>&1; then
          sleep 2
          continue
        fi

        wait_for_ironbar

        socket_path=""
        if ! socket_path="$(find_hypr_socket)"; then
          sleep 1
          continue
        fi

        if ! update_state; then
          sleep 1
          continue
        fi

        while read -r _event; do
          event_name="''${_event%%>>*}"

          if ! should_refresh_for_event "$event_name"; then
            continue
          fi

          if ! ironbar ping >/dev/null 2>&1; then
            break
          fi

          if ! update_state; then
            break
          fi
        done < <(socat -U "UNIX-CONNECT:$socket_path" - 2>/dev/null)

        sleep 1
      done
    '';
  });

  desktopEnd =
    [
      musicModule
      aiProcessesModule
      cpuModule
      memoryModule
      diskModule
      volumeModule
    ]
    ++ lib.optional hasBattery batteryModule
    ++ [
      notificationsModule
      trayModule
      clockModule
      powerMenuModule
    ];

  compactEnd =
    [
      aiProcessesModule
      cpuModule
      memoryModule
      diskModule
      volumeModule
    ]
    ++ lib.optional hasBattery batteryModule
    ++ [ powerMenuModule ];

  defaultBar = barDefaults // {
    name = "ironbar-default";
    height = 40;
    margin = {
      top = 8;
      left = 12;
      right = 12;
      bottom = 0;
    };
    start = desktopStart;
    center = desktopCenter;
    end = desktopEnd;
  };

  ironbarConfig = defaultBar // {
    monitors = {
      "DP-2" = barDefaults // {
        name = "ironbar-dp2";
        height = 36;
        margin = {
          top = 8;
          left = 8;
          right = 8;
          bottom = 0;
        };
        start = compactStart;
        center = compactCenter;
        end = compactEnd;
      };
      "DP-3" = barDefaults // {
        name = "ironbar-dp3";
        height = 40;
        margin = {
          top = 8;
          left = 12;
          right = 12;
          bottom = 0;
        };
        start = desktopStartSecondary;
        center = desktopCenter;
        end = desktopEnd;
      };
    };
  };
in
{
  home.packages = [
    pkgs.ironbar
    (pkgs.writeShellApplication {
      name = "ironbar-toggle-power-menu";
      runtimeInputs = [
        pkgs.ironbar
        pkgs.jq
      ];
      text = ''
        active_monitor="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor // empty')"

        if [ -z "$active_monitor" ]; then
          active_monitor="$(hyprctl monitors -j 2>/dev/null | jq -r 'first(.[] | select(.focused == true) | .name) // empty')"
        fi

        case "$active_monitor" in
          DP-2)
            bar_name="ironbar-dp2"
            ;;
          DP-3)
            bar_name="ironbar-dp3"
            ;;
          *)
            bar_name="ironbar-default"
            ;;
        esac

        exec ironbar bar "$bar_name" toggle-popup power-menu
      '';
    })
  ];

  xdg.configFile."ironbar/config.json" = {
    force = true;
    text = builtins.toJSON ironbarConfig;
  };

  xdg.configFile."ironbar/style.css" = {
    force = true;
    text = ''
      @define-color panel_bg #1e2030;
      @define-color panel_surface #24273a;
      @define-color panel_surface_alt #363a4f;
      @define-color panel_surface_alt_2 #494d64;
      @define-color panel_border #5b6078;
      @define-color panel_fg #cad3f5;
      @define-color panel_muted #a5adcb;
      @define-color panel_accent #8aadf4;
      @define-color panel_accent_soft #b7bdf8;
      @define-color panel_accent_alt #c6a0f6;
      @define-color panel_good #a6da95;
      @define-color panel_warn #eed49f;
      @define-color panel_bad #ed8796;
      @define-color panel_info #7dc4e4;
      @define-color panel_teal #8bd5ca;
      @define-color panel_peach #f5a97f;

      * {
      border: none;
      border-radius: 0;
      box-shadow: none;
      color: @panel_fg;
      font-family: "Noto Sans CJK JP", "Symbols Nerd Font", sans-serif;
      font-size: 12px;
      }

      .background {
      background: transparent;
      }

      #bar {
      background-color: alpha(@panel_bg, 0.97);
      border: 1px solid alpha(@panel_surface_alt_2, 0.96);
      border-radius: 14px;
      box-shadow: 0 16px 38px alpha(black, 0.48);
      padding: 4px 6px;
      }

      #bar #start,
      #bar #center,
      #bar #end {
      background: transparent;
      }

      #bar separator,
      #bar .separator,
      #bar undershoot,
      #bar overshoot {
      min-width: 0;
      min-height: 0;
      margin: 0;
      padding: 0;
      background: transparent;
      border: none;
      box-shadow: none;
      opacity: 0;
      }

      #bar *:focus,
      #bar *:focus-visible {
      outline: none;
      box-shadow: none;
      }

      .widget-container {
      margin: 0 3px;
      }

      .widget,
      button,
      menubutton {
      background-color: alpha(@panel_surface, 0.96);
      border: none;
      border-radius: 11px;
      min-height: 28px;
      padding: 0 10px;
      transition: background-color 160ms ease, border-color 160ms ease, color 160ms ease;
      }

      .widget:hover,
      button:hover,
      menubutton:hover {
      background-color: alpha(@panel_surface_alt, 0.98);
      }

      #power-trigger {
        background-image: linear-gradient(135deg, @panel_accent_alt, @panel_accent);
        color: @panel_bg;
        font-weight: 800;
      }

      #power-trigger:hover {
        background-image: linear-gradient(135deg, @panel_accent_soft, @panel_accent);
      }

      .workspace-pill {
      background: transparent;
      border: none;
      margin: 0;
      min-height: 0;
      padding: 0;
      }

      .workspace-pill:hover {
      background: transparent;
      }

      .workspace-pill button {
      background-color: alpha(@panel_surface, 0.94);
      border: none;
      border-radius: 9px;
      min-height: 20px;
      width: 30px;
      min-width: 30px;
      max-width: 30px;
      padding: 0;
      }

      .workspace-pill button label {
      font-size: 10px;
      line-height: 0.74;
      margin: 0;
      }

      .workspace-pill.focused button {
      background-image: linear-gradient(135deg, @panel_accent_alt, @panel_accent);
      color: @panel_bg;
      font-weight: 800;
      }

      .workspace-pill.focused button:hover {
      background-image: linear-gradient(135deg, @panel_accent_soft, @panel_accent);
      }

      #focused-window {
      min-width: 240px;
      }

      #focused-window {
      background-color: alpha(@panel_surface_alt, 0.72);
      padding-left: 16px;
      padding-right: 16px;
      }

      #music {
      min-width: 120px;
      background-image: linear-gradient(90deg, alpha(@panel_accent_alt, 0.24), alpha(@panel_accent, 0.16));
      }

      #cpu,
      #memory,
      #disk,
      #ai-processes,
      #volume,
      #network,
      #bluetooth,
      #battery,
      #clock,
      #notifications,
      #tray,
      #power-menu {
      font-weight: 700;
      }

      #ai-processes {
      padding-left: 8px;
      padding-right: 8px;
      }

      #cpu,
      #memory,
      #disk {
      padding-left: 8px;
      padding-right: 8px;
      }

      #ai-processes,
      #ai-processes label {
      color: @panel_accent;
      }

      #ai-processes-box,
      #cpu-box,
      #memory-box,
      #disk-box,
      #codex-process,
      #claude-process {
      background: transparent;
      }

      #cpu-icon,
      #memory-icon,
      #disk-icon,
      #codex-icon,
      #claude-icon {
      margin-right: 6px;
      }

      #codex-count {
      margin-right: 12px;
      }

      #codex-count,
      #claude-count,
      #cpu-icon,
      #memory-icon,
      #disk-icon,
      #cpu-value,
      #memory-value,
      #disk-value {
      color: @panel_fg;
      font-weight: 400;
      }

      #volume label {
      color: @panel_info;
      }

      #network label {
      color: @panel_teal;
      }

      #bluetooth label,
      #clock label {
      color: @panel_accent_soft;
      }

      #notifications label {
      color: @panel_accent_alt;
      }

      #power-menu label {
      color: @panel_peach;
      }

      .battery.warning label {
      color: @panel_warn;
      }

      .battery.critical label {
      color: @panel_bad;
      }

      .notifications .count {
      background-color: @panel_accent_alt;
      border-radius: 999px;
      color: @panel_bg;
      font-size: 10px;
      font-weight: 800;
      margin-left: 4px;
      min-height: 18px;
      min-width: 18px;
      padding: 0 5px;
      }

      .tray {
      padding-left: 6px;
      padding-right: 6px;
      }

      .tray .item {
      margin: 0 2px;
      }

      .popup {
      background-color: alpha(@panel_bg, 0.99);
      border: 1px solid alpha(@panel_surface_alt_2, 0.96);
      border-radius: 18px;
      box-shadow: 0 22px 50px alpha(black, 0.5);
      padding: 12px;
      }

      .popup label {
      color: @panel_fg;
      }

      .popup button {
      min-height: 36px;
      }

      .popup scale trough {
      background-color: alpha(@panel_surface_alt, 0.96);
      border-radius: 999px;
      min-height: 8px;
      }

      .popup scale highlight {
      background-image: linear-gradient(90deg, @panel_accent_alt, @panel_accent);
      border-radius: 999px;
      }

      .popup scale slider {
      background-color: @panel_fg;
      border-radius: 999px;
      min-height: 18px;
      min-width: 18px;
      }

      .popup-clock .calendar-clock {
      color: @panel_accent_soft;
      font-size: 28px;
      font-weight: 800;
      margin-bottom: 12px;
      }

      .popup-clock calendar {
      background: transparent;
      color: @panel_fg;
      }

      .popup-clock calendar:selected {
      background-color: @panel_accent_alt;
      color: @panel_bg;
      }

      .popup-music .album-art {
      border-radius: 16px;
      }

      .popup-music .title label {
      font-size: 18px;
      font-weight: 800;
      }

      .popup-music .artist label,
      .popup-music .album label {
      color: @panel_muted;
      }

      .popup-volume .device-box,
      .popup-volume .app-box,
      .popup-bluetooth .device {
      background-color: alpha(@panel_surface, 0.92);
      border: 1px solid alpha(@panel_surface_alt_2, 0.72);
      border-radius: 16px;
      padding: 10px;
      }

      .popup-power-menu {
      min-width: 280px;
      }

      .popup-power-menu #power-heading {
      color: @panel_accent_soft;
      font-size: 18px;
      font-weight: 800;
      margin-bottom: 10px;
      }

      .popup-power-menu .power-actions {
      background: transparent;
      }

      .popup-power-menu .power-action {
      background-color: alpha(@panel_surface_alt, 0.98);
      border: 1px solid alpha(@panel_surface_alt_2, 0.78);
      min-height: 54px;
      min-width: 54px;
      padding: 0;
      }

      .popup-power-menu .power-action:hover {
      background-color: alpha(@panel_accent_alt, 0.18);
      border-color: alpha(@panel_accent_soft, 0.64);
      }

      .popup-power-menu #power-uptime {
      color: @panel_muted;
      margin-top: 10px;
      }
    '';
  };

  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      "control-center-layer" = "top";
      "layer-shell" = true;
      "layer-shell-cover-screen" = false;
      "fit-to-screen" = false;
      cssPriority = "user";
      "control-center-margin-top" = 56;
      "control-center-margin-right" = 14;
      "control-center-margin-bottom" = 14;
      "control-center-width" = 400;
      "control-center-height" = 700;
      "notification-2fa-action" = true;
      "notification-inline-replies" = false;
      "notification-icon-size" = 48;
      "notification-body-image-height" = 120;
      "notification-body-image-width" = 220;
      "notification-window-width" = 400;
      timeout = 4;
      "timeout-low" = 2;
      "notification-grouping" = true;
      "image-visibility" = "never";
      "transition-time" = 120;
      widgets = [
        "title"
        "dnd"
        "notifications"
      ];
      "widget-config" = {
        notifications = {
          vexpand = true;
        };
      };
      scripts = {
        "claude-code-sound-app-name" = {
          exec = "${pkgs.pipewire}/bin/pw-play --volume 0.75 ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message.oga";
          "app-name" = "^Claude Code$";
          run-on = "receive";
        };
        "claude-code-sound-summary" = {
          exec = "${pkgs.pipewire}/bin/pw-play --volume 0.75 ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message.oga";
          summary = "^Claude Code$";
          run-on = "receive";
        };
        "ghostty-sound-summary" = {
          exec = "${pkgs.pipewire}/bin/pw-play --volume 0.75 ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message.oga";
          summary = "^Ghostty$";
          run-on = "receive";
        };
        "ghostty-sound-desktop-entry" = {
          exec = "${pkgs.pipewire}/bin/pw-play --volume 0.75 ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message.oga";
          "desktop-entry" = "^com\\.mitchellh\\.ghostty(\\.quick\\.(left|right))?$";
          run-on = "receive";
        };
      };
    };
    style = ''
      * {
      all: unset;
      font-size: 14px;
      font-family: "Noto Sans CJK JP", "Symbols Nerd Font", sans-serif;
      transition: 200ms;
      }

      trough highlight {
      background: #cad3f5;
      }

      scale {
      margin: 0 7px;
      }

      scale trough {
      margin: 0rem 1rem;
      min-height: 8px;
      min-width: 70px;
      border-radius: 12.6px;
      }

      trough slider {
      margin: -10px;
      border-radius: 12.6px;
      box-shadow: 0 0 2px rgba(0, 0, 0, 0.8);
      transition: all 0.2s ease;
      background-color: #8aadf4;
      }

      trough slider:hover {
      box-shadow: 0 0 2px rgba(0, 0, 0, 0.8), 0 0 8px #8aadf4;
      }

      trough {
      background-color: #363a4f;
      }

      .notification-background {
      box-shadow: 0 0 8px 0 rgba(0, 0, 0, 0.8), inset 0 0 0 1px #494d64;
      border-radius: 12.6px;
      margin: 10px;
      background: #1e2030;
      color: #cad3f5;
      padding: 0;
      }

      .notification-background .notification {
      padding: 7px;
      border-radius: 12.6px;
      }

      .notification-background .notification.critical {
      box-shadow: inset 0 0 7px 0 #ed8796;
      }

      .notification .notification-content {
      margin: 7px;
      }

      .notification .notification-content overlay {
      margin: 4px;
      }

      .notification-content .summary {
      color: #cad3f5;
      }

      .notification-content .time {
      color: #a5adcb;
      }

      .notification-content .body {
      color: #b8c0e0;
      }

      .notification > *:last-child > * {
      min-height: 3.4em;
      }

      .notification-background .close-button {
      margin: 7px;
      padding: 2px;
      border-radius: 6.3px;
      color: #24273a;
      background-color: #ed8796;
      }

      .notification-background .close-button:hover {
      background-color: #ee99a0;
      }

      .notification-background .close-button:active {
      background-color: #f5bde6;
      }

      .notification .notification-action {
      border-radius: 7px;
      color: #cad3f5;
      box-shadow: inset 0 0 0 1px #494d64;
      margin: 4px;
      padding: 8px;
      font-size: 0.2rem;
      background-color: #363a4f;
      }

      .notification .notification-action:hover {
      background-color: #494d64;
      }

      .notification .notification-action:active {
      background-color: #5b6078;
      }

      .notification.critical progress {
      background-color: #ed8796;
      }

      .notification.low progress,
      .notification.normal progress {
      background-color: #8aadf4;
      }

      .notification progress,
      .notification trough,
      .notification progressbar {
      border-radius: 12.6px;
      padding: 3px 0;
      }

      .control-center {
      box-shadow: 0 0 8px 0 rgba(0, 0, 0, 0.8), inset 0 0 0 1px #363a4f;
      border-radius: 12.6px;
      background-color: #24273a;
      color: #cad3f5;
      padding: 14px;
      }

      .control-center .notification-background {
      border-radius: 7px;
      box-shadow: inset 0 0 0 1px #494d64;
      margin: 4px 10px;
      }

      .control-center .notification-background .notification {
      border-radius: 7px;
      }

      .control-center .notification-background .notification.low {
      opacity: 0.8;
      }

      .control-center .widget-title > label {
      color: #cad3f5;
      font-size: 1.3em;
      }

      .control-center .widget-title button {
      border-radius: 7px;
      color: #cad3f5;
      background-color: #363a4f;
      box-shadow: inset 0 0 0 1px #494d64;
      padding: 8px;
      }

      .control-center .widget-title button:hover {
      background-color: #494d64;
      }

      .control-center .widget-title button:active {
      background-color: #5b6078;
      }

      .control-center .notification-group {
      margin-top: 10px;
      }

      .control-center .notification-group:focus .notification-background {
      background-color: #363a4f;
      }

      scrollbar slider {
      margin: -3px;
      opacity: 0.8;
      }

      scrollbar trough {
      margin: 2px 0;
      }

      .widget-dnd {
      margin-top: 5px;
      border-radius: 8px;
      font-size: 1.1rem;
      }

      .widget-dnd > switch {
      font-size: initial;
      border-radius: 8px;
      background: #363a4f;
      box-shadow: none;
      }

      .widget-dnd > switch:checked {
      background: #8aadf4;
      }

      .widget-dnd > switch slider {
      background: #494d64;
      border-radius: 8px;
      }

      .widget-mpris-player {
      background: #363a4f;
      border-radius: 12.6px;
      color: #cdd6f4;
      }

      .mpris-overlay {
      background-color: #363a4f;
      opacity: 0.9;
      padding: 15px 10px;
      }

      .widget-mpris-album-art {
      -gtk-icon-size: 100px;
      border-radius: 12.6px;
      margin: 0 10px;
      }

      .widget-mpris-title {
      font-size: 1.2rem;
      color: #cad3f5;
      }

      .widget-mpris-subtitle {
      font-size: 1rem;
      color: #b8c0e0;
      }

      .widget-mpris button {
      border-radius: 12.6px;
      color: #cad3f5;
      margin: 0 5px;
      padding: 2px;
      }

      .widget-mpris button image {
      -gtk-icon-size: 1.8rem;
      }

      .widget-mpris button:hover {
      background-color: #363a4f;
      }

      .widget-mpris button:active {
      background-color: #494d64;
      }

      .widget-mpris button:disabled {
      opacity: 0.5;
      }

      .widget-menubar > box > .menu-button-bar > button > label {
      font-size: 3rem;
      padding: 0.5rem 2rem;
      }

      .widget-menubar > box > .menu-button-bar > :last-child {
      color: #ed8796;
      }

      .power-buttons button:hover,
      .powermode-buttons button:hover,
      .screenshot-buttons button:hover {
      background: #363a4f;
      }

      .control-center .widget-label > label {
      color: #cad3f5;
      font-size: 2rem;
      }

      .widget-buttons-grid {
      padding-top: 1rem;
      }

      .widget-buttons-grid > flowbox > flowboxchild > button label {
      font-size: 2.5rem;
      }

      .widget-volume {
      padding: 1rem 0;
      }

      .widget-volume label {
      color: #7dc4e4;
      padding: 0 1rem;
      }

      .widget-volume trough highlight {
      background: #7dc4e4;
      }

      .widget-backlight trough highlight {
      background: #eed49f;
      }

      .widget-backlight label {
      font-size: 1.5rem;
      color: #eed49f;
      }

      .widget-backlight .KB {
      padding-bottom: 1rem;
      }

      .image {
      padding-right: 0.5rem;
      }
    '';
  };

  home.activation.stopHyprpanel = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${systemctlBin} --user stop hyprpanel.service 2>/dev/null || true
  '';

  systemd.user.services.ironbar = {
    Unit = {
      Description = "Ironbar status bar";
      Documentation = "https://github.com/JakeStanger/ironbar/wiki";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
      X-Restart-Triggers = [
        "${config.xdg.configFile."ironbar/config.json".source}"
        "${config.xdg.configFile."ironbar/style.css".source}"
      ];
    };

    Service = {
      Environment = [
        "IRONBAR_CONFIG=%h/.config/ironbar/config.json"
        "IRONBAR_CSS=%h/.config/ironbar/style.css"
        "IRONBAR_LOG=warn"
        "IRONBAR_FILE_LOG=warn"
      ];
      ExecStart = ironbarBin;
      ExecReload = "${ironbarBin} reload";
      Restart = "on-failure";
      KillMode = "mixed";
    };

    Install = {
      WantedBy = [ config.wayland.systemd.target ];
    };
  };

  systemd.user.services.ironbar-workspace-state = {
    Unit = {
      Description = "Ironbar workspace state updater";
      PartOf = [
        config.wayland.systemd.target
        "ironbar.service"
      ];
      Wants = [ "ironbar.service" ];
      After = [
        config.wayland.systemd.target
        "ironbar.service"
      ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
      X-Restart-Triggers = [
        "${config.xdg.configFile."ironbar/config.json".source}"
        "${config.xdg.configFile."ironbar/style.css".source}"
        workspaceStateScript
      ];
    };

    Service = {
      ExecStart = workspaceStateScript;
      Restart = "always";
      RestartSec = 1;
      KillMode = "mixed";
    };

    Install = {
      WantedBy = [ config.wayland.systemd.target ];
    };
  };
}
