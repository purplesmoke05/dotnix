{ config, lib, pkgs, ... }:

let
  bladebroSupported = lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.bladebro;
  herdrConfig = { soundEnabled }:
    ''
      [ui.sound]
      enabled = ${lib.boolToString soundEnabled}

      [advanced]
      scrollback_limit_bytes = 100000000

      [experimental]
      kitty_graphics = true

      [ui.sidebar.agents]
      row_gap = 0
      rows = [
        ["state_icon", "$title"],
        ["$provider", "$limit"],
        ["$context"],
      ]

      [keys]
      focus_pane_up = "prefix+k"
      focus_pane_down = "prefix+j"
      navigate_pane_up = "k"
      navigate_pane_down = "j"
      navigate_workspace_up = "ctrl+p"
      navigate_workspace_down = "ctrl+n"
      # Keep the workspace picker reachable when the IME consumes plain `w`. / IME が平文の `w` を消費しても workspace picker を開けるようにする。
      workspace_picker = ["prefix+w", "prefix+ctrl+w"]
      # Use Ctrl chords for workspace switching while the IME is enabled. / IME 有効時の workspace 切り替えには Ctrl chord を使う。
      previous_workspace = "prefix+ctrl+p"
      next_workspace = "prefix+ctrl+n"
      previous_agent = "prefix+["
      next_agent = "prefix+]"

      [[keys.command]]
      key = "prefix+t"
      type = "plugin_action"
      command = "herdr-navigator.open"
      description = "navigator: jump to anything"

      [[keys.command]]
      key = "prefix+ctrl+r"
      type = "plugin_action"
      command = "persiyanov.reviewr.toggle"
      description = "reviewr: toggle pane"

      [[keys.command]]
      key = "prefix+shift+b"
      type = "shell"
      command = "${pkgs.herdr}/bin/herdr plugin pane open --plugin official.browser --entrypoint browser --placement overlay --focus"
      description = "browser: open overlay"

      [[keys.command]]
      key = "prefix+up"
      type = "plugin_action"
      command = "cloudmanic.herdr-plus.projects"
      description = "herdr-plus: projects"

      [[keys.command]]
      key = "prefix+down"
      type = "plugin_action"
      command = "cloudmanic.herdr-plus.quick-actions"
      description = "herdr-plus: quick actions"

      [[keys.command]]
      key = "prefix+m"
      type = "plugin_action"
      command = "nicosuave.memex.palette"
      description = "memex: session palette"

      [[keys.command]]
      key = "ctrl+shift+u"
      type = "plugin_action"
      command = "usagebar.open-limits"
      description = "agent usage: open limits"

      [[keys.command]]
      key = "ctrl+shift+m"
      type = "plugin_action"
      command = "usagebar.refresh"
      description = "agent usage: refresh meters"

      [[keys.command]]
      key = "prefix+shift+g"
      type = "plugin_action"
      command = "worktrunk.open"
      description = "worktrunk: switch or create from default branch"

      [[keys.command]]
      key = "prefix+shift+c"
      type = "plugin_action"
      command = "worktrunk.open-current"
      description = "worktrunk: switch or create from current branch"

      [[keys.command]]
      key = "prefix+shift+d"
      type = "plugin_action"
      command = "worktrunk.remove"
      description = "worktrunk: remove worktree"
    '';
  herdrProfiles = {
    default = herdrConfig { soundEnabled = true; };
    quiet = herdrConfig { soundEnabled = false; };
  };
  herdrProfileDirectory = "${config.xdg.configHome}/herdr/profiles";
  herdrStateDirectory = "${config.xdg.stateHome}/herdr";
  herdrActiveConfig = "${herdrStateDirectory}/config.toml";
  herdrPlugins = [
    pkgs.herdr-reviewr-plugin
    pkgs.herdr-browser-plugin
    pkgs.herdr-plus-plugin
    pkgs.herdr-memex-plugin
    pkgs.herdr-navigator-plugin
    pkgs.herdr-agent-usage-plugin
    pkgs.herdr-worktrunk-plugin
  ];
  herdrSound = pkgs.writeShellApplication {
    name = "herdr-sound";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.herdr
      pkgs.jq
    ];
    text = ''
      profile_directory=${lib.escapeShellArg herdrProfileDirectory}
      state_directory=${lib.escapeShellArg herdrStateDirectory}
      active_config=${lib.escapeShellArg herdrActiveConfig}

      usage() {
        printf 'Usage: herdr-sound <list|current|set PROFILE>\n' >&2
      }

      current_profile() {
        local active_target profile_name profile_path profile_target

        active_target="$(readlink -f "$active_config" 2>/dev/null || true)"
        for profile_path in "$profile_directory"/*.toml; do
          [[ -e "$profile_path" ]] || continue
          profile_target="$(readlink -f "$profile_path")"
          if [[ "$profile_target" == "$active_target" ]]; then
            profile_name="$(basename "$profile_path" .toml)"
            printf '%s\n' "$profile_name"
            return 0
          fi
        done

        printf 'No managed Herdr sound profile is active.\n' >&2
        return 1
      }

      list_profiles() {
        local active_profile profile_name profile_path

        active_profile="$(current_profile 2>/dev/null || true)"
        for profile_path in "$profile_directory"/*.toml; do
          [[ -e "$profile_path" ]] || continue
          profile_name="$(basename "$profile_path" .toml)"
          if [[ "$profile_name" == "$active_profile" ]]; then
            printf '* %s\n' "$profile_name"
          else
            printf '  %s\n' "$profile_name"
          fi
        done
      }

      set_profile() {
        local candidate profile_name status_json temporary_link
        profile_name="$1"

        if [[ ! "$profile_name" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
          printf 'Invalid Herdr sound profile: %s\n' "$profile_name" >&2
          return 2
        fi

        candidate="$profile_directory/$profile_name.toml"
        if [[ ! -e "$candidate" ]]; then
          printf 'Unknown Herdr sound profile: %s\n' "$profile_name" >&2
          list_profiles >&2
          return 2
        fi

        HERDR_CONFIG_PATH="$candidate" herdr config check
        mkdir -p "$state_directory"
        if [[ -e "$active_config" && ! -L "$active_config" ]]; then
          printf 'Refusing to replace non-symlink config: %s\n' "$active_config" >&2
          return 1
        fi

        temporary_link="$state_directory/.config.toml.$$"
        trap 'rm -f -- "$temporary_link"' EXIT
        ln -s "$candidate" "$temporary_link"
        mv -Tf "$temporary_link" "$active_config"

        status_json="$(herdr status server --json)"
        if jq -e '.running == true' >/dev/null <<<"$status_json"; then
          herdr server reload-config
          printf 'Herdr sound profile switched to %s and reloaded.\n' "$profile_name"
        else
          printf 'Herdr sound profile switched to %s; it will be used on the next launch.\n' "$profile_name"
        fi
      }

      case "''${1:-}" in
        list)
          [[ $# -eq 1 ]] || { usage; exit 2; }
          list_profiles
          ;;
        current)
          [[ $# -eq 1 ]] || { usage; exit 2; }
          current_profile
          ;;
        set)
          [[ $# -eq 2 ]] || { usage; exit 2; }
          set_profile "$2"
          ;;
        *)
          usage
          exit 2
          ;;
      esac
    '';
  };
in
{
  home.packages = with pkgs;
    [
      hunk
      herdr
      herdrSound
      pi
      prime-agent
      worktrunk
    ]
    ++ lib.optionals bladebroSupported [
      bladebro
    ];

  # Load Bladebro through Pi's local stdio extension. / Pi のローカル stdio 拡張として Bladebro を読み込む。
  home.file = lib.mkIf bladebroSupported {
    ".pi/agent/extensions/bladebro.ts".source = "${pkgs.bladebro}/share/pi/extensions/bladebro.ts";
  };

  # Protect persistent browser sessions, cookies, and artifacts. / 永続ブラウザセッション・Cookie・成果物を保護する。
  home.activation.ensureBladebroStateDirectory = lib.mkIf bladebroSupported (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -d -m 0700 \
        ${lib.escapeShellArg "${config.home.homeDirectory}/.blade"}
    ''
  );

  # Keep the selected sound profile mutable while Nix owns every profile definition. / 各プロファイル定義を Nix で管理しつつ、選択中の通知音プロファイルは可変に保つ。
  home.activation.initializeHerdrSoundProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -d -m 0700 \
      ${lib.escapeShellArg herdrStateDirectory}
    if [[ ! -e ${lib.escapeShellArg herdrActiveConfig} && ! -L ${lib.escapeShellArg herdrActiveConfig} ]]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/ln -s \
        ${lib.escapeShellArg "${herdrProfileDirectory}/default.toml"} \
        ${lib.escapeShellArg herdrActiveConfig}
    fi
  '';

  # Keep the pinned plugin roots registered for every Herdr session. / 固定したプラグインルートを全 Herdr session に登録する。
  home.activation.linkHerdrPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatMapStringsSep "\n"
      (plugin: ''
        $DRY_RUN_CMD ${pkgs.herdr}/bin/herdr plugin link ${lib.escapeShellArg "${plugin}"} --enabled
      '')
      herdrPlugins
  );

  xdg.configFile =
    lib.mapAttrs'
      (profileName: text:
        lib.nameValuePair "herdr/profiles/${profileName}.toml" { inherit text; })
      herdrProfiles
    // {
      "herdr/config.toml".source = config.lib.file.mkOutOfStoreSymlink herdrActiveConfig;
      # Let Herdr Plus own worktree layouts without racing reviewr's auto-open hook. / Herdr Plus に worktree layout を任せ、reviewr の自動起動との競合を避ける。
      "herdr/plugins/config/persiyanov.reviewr/config.toml".text = ''
        auto_open = false
      '';
      # Refresh the local session-history index when Herdr starts. / Herdr 起動時にローカルの session 履歴 index を更新する。
      "herdr/plugins/config/nicosuave.memex/config.toml".text = ''
        index_on_startup = true
      '';
      # Keep Agent Usage notifications opt-in while exposing context and rate-limit meters. / コンテキスト・レート制限表示を有効にしつつ、Agent Usage 通知は明示的な選択制に保つ。
      "herdr/plugins/config/usagebar/config.toml".text = ''
        [notify]
        enabled = false
        remaining_thresholds = [50, 20, 10, 5]
      '';
      # Open Worktrunk checkouts as native Herdr worktree workspaces. / Worktrunk の checkout を Herdr ネイティブの worktree workspace として開く。
      "herdr/plugins/config/worktrunk/config.toml".text = ''
        open_mode = "workspace"
        show_remote_branches = false
      '';
    };
}
