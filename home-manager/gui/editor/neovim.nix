{pkgs, ...}: {
  # Neovim editor configuration
  # - Aliases for vi and vim commands
  # - Plugin management
  # - Language support and tools
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    # Plugin configuration
    # - Treesitter for syntax highlighting and parsing
    # - Telescope for fuzzy finding
    plugins = with pkgs.vimPlugins; [
      # Syntax highlighting and parsing
      (nvim-treesitter.withPlugins (plugins:
        with plugins; [
          tree-sitter-markdown
          tree-sitter-nix
          # ...
        ]))
      telescope-nvim
      # ...
    ];

    # External tools and language servers
    # - ripgrep: Fast text search
    # - biome: JavaScript/TypeScript formatter
    # - ESLint: JavaScript linter
    # - Prettier: Code formatter
    # - TypeScript language server
    extraPackages = with pkgs; [
      ripgrep
      biome
    ];

    # Additional Lua configuration
    # - Custom keybindings
    # - Plugin settings
    # - Editor behavior
    extraLuaConfig = ''
      -- Lua configuration goes here
    '';
  };
}
