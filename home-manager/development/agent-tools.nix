{ config, lib, pkgs, ... }:

let
  bladebroSupported = lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.bladebro;
in
{
  home.packages = with pkgs;
    [
      hunk
      herdr
      pi
    ]
    ++ lib.optionals bladebroSupported [
      bladebro
    ];

  # Load Bladebro through Pi's local stdio extension. / Pi のローカル stdio 拡張として Bladebro を読み込む。
  home.file = lib.mkIf bladebroSupported {
    ".pi/agent/extensions/bladebro.ts".source = "${pkgs.bladebro}/share/pi/extensions/bladebro.ts";
  };

  # Protect persistent browser sessions, cookies, and artifacts. / 永続ブラウザセッション・Cookie・成果物を保護する。
  home.activation = lib.mkIf bladebroSupported {
    ensureBladebroStateDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -d -m 0700 \
        ${lib.escapeShellArg "${config.home.homeDirectory}/.blade"}
    '';
  };

  # Keep prefix navigation and add Emacs-style shortcuts that work with the IME. / prefix 操作を維持し、IME でも使える Emacs 風ショートカットを追加する。
  xdg.configFile."herdr/config.toml".text = ''
    [ui.sound]
    enabled = true

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
}
