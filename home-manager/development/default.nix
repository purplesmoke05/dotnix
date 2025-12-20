{ pkgs, ... }: {
  # Development tools and programming languages
  # - Go: Systems programming and web services
  # - Deno: Modern JavaScript/TypeScript runtime
  # - Bun: Fast JavaScript runtime and package manager
  # - Zig: Systems programming language
  # - Rust: Systems programming with memory safety
  # - uv: Fast Python package installer
  # - Foundry: Ethereum development toolkit (forge, cast, anvil, chisel)
  # - Solc: Solidity compiler
  # - radeontop: Monitor AMD GPU utilization. / AMD GPU の利用状況を監視。
  home.packages = with pkgs; [
    go
    bun
    zig
    uv
    sqlite
    volta
    codex
    claude-code
    gemini-cli
    ctop
    iftop
    radeontop
    grim
    slurp
    wl-clipboard
    wl-screenrec
    killall
    ripgrep
    foundry
    solc
    slither-analyzer
    postgresql.pg_config
    pkg-config
  ];

  # Environment variables for Volta
  home.sessionVariables = {
    VOLTA_HOME = "$HOME/.volta";
  };

  # Add Volta binary directory to PATH
  home.sessionPath = [
    "$VOLTA_HOME/bin"
  ];
}
