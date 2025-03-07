{pkgs, ...}: {
  # Development tools and programming languages
  # - Go: Systems programming and web services
  # - Deno: Modern JavaScript/TypeScript runtime
  # - Bun: Fast JavaScript runtime and package manager
  # - Zig: Systems programming language
  # - Rust: Systems programming with memory safety
  # - uv: Fast Python package installer
  home.packages = with pkgs; [
    go
    deno
    bun
    zig
    uv
    sqlite
  ];
}
