{ config, lib, pkgs, ... }:

let
  bladebroSupported = lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.bladebro;
  herdrConfig = { soundEnabled }:
    ''
      [ui.sound]
      enabled = ${lib.boolToString soundEnabled}

      [advanced]
      scrollback_limit_bytes = 100000000

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
    '';
  herdrProfiles = {
    default = herdrConfig { soundEnabled = true; };
    quiet = herdrConfig { soundEnabled = false; };
  };
  herdrProfileDirectory = "${config.xdg.configHome}/herdr/profiles";
  herdrStateDirectory = "${config.xdg.stateHome}/herdr";
  herdrActiveConfig = "${herdrStateDirectory}/config.toml";
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

  xdg.configFile =
    lib.mapAttrs'
      (profileName: text:
        lib.nameValuePair "herdr/profiles/${profileName}.toml" { inherit text; })
      herdrProfiles
    // {
      "herdr/config.toml".source = config.lib.file.mkOutOfStoreSymlink herdrActiveConfig;
    };
}
