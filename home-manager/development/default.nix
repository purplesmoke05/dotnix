{ pkgs, ... }: {
  # Development tools and programming languages
  # - Go: Systems programming and web services
  # - Deno: Modern JavaScript/TypeScript runtime
  # - Bun: Fast JavaScript runtime and package manager
  # - Zig: Systems programming language
  # - Rust: Systems programming with memory safety
  # - uv: Fast Python package installer
  # - mise: Runtime and tool version manager. / ランタイム・ツールのバージョン管理。
  # - Foundry: Ethereum development toolkit (forge, cast, anvil, chisel)
  # - Solc: Solidity compiler
  # - radeontop: Monitor AMD GPU utilization. / AMD GPU の利用状況を監視。
  programs.mise.enable = true;

  home.packages = with pkgs; [
    go
    bun
    nodejs_24
    zig
    uv
    sqlite
    volta
    codex
    opencode
    confluence-cli
    claude-code
    rtk
    pi
    hunk
    herdr
    devbox
    ctop
    iftop
    btop
    radeontop
    grim
    slurp
    wl-clipboard
    killall
    ripgrep
    foundry
    solc
    slither-analyzer
    libpq
    libpq.pg_config
    pkg-config
  ];

  # Environment variables for Volta
  home.sessionVariables = {
    VOLTA_HOME = "$HOME/.volta";
    PG_CONFIG = "${pkgs.libpq}/bin/pg_config";
    LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [ pkgs.libpq ]}:$LD_LIBRARY_PATH";
  };

  # Add Volta binary directory to PATH
  home.sessionPath = [
    "$VOLTA_HOME/bin"
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
