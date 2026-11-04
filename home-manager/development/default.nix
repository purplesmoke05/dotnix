{ pkgs, ... }: {
  imports = [
    ./agent-tools.nix
    ./headroom.nix
  ];

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
    python3
    sqlite
    codex
    opencode
    confluence-cli
    officecli
    claude-code
    rtk
    devbox
    iftop
    btop
    radeontop
    grim
    slurp
    wl-clipboard
    killall
    ripgrep
    libpq
    libpq.pg_config
    pkg-config
  ];

  home.sessionVariables = {
    PG_CONFIG = "${pkgs.libpq}/bin/pg_config";
    LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [ pkgs.libpq ]}:$LD_LIBRARY_PATH";
    # Enable opencode experimental background subagents (Task tool background mode).
    OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true";
  };

  # Add Volta binary directory to PATH
  home.sessionPath = [
    "$VOLTA_HOME/bin"
  ];
}
