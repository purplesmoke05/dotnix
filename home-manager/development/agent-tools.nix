{ pkgs, ... }:

{
  home.packages = with pkgs; [
    hunk
    herdr
  ];

  # Keep prefix navigation and add Emacs-style shortcuts that work with the IME. / prefix 操作を維持し、IME でも使える Emacs 風ショートカットを追加する。
  xdg.configFile."herdr/config.toml".text = ''
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
