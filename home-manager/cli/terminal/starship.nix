{ pkgs, ... }: {
  programs.starship = {
    enable = true;
    settings = {
      # Define format as a single-line Nix string without $ escaping
      format = "$golang$rust$python$nodejs$nix_shell$cmd_duration$line_break$username@$hostname $directory$git_branch$character";

      # Nerd Font Symbols
      aws.symbol = "  ";
      buf.symbol = " ";
      c.symbol = " ";
      conda.symbol = " ";
      dart.symbol = " ";
      directory.read_only = " ";
      docker_context.symbol = " ";
      elixir.symbol = " ";
      elm.symbol = " ";
      git_branch.symbol = " ";
      golang.symbol = " ";
      guix_shell.symbol = " ";
      haskell.symbol = " ";
      haxe.symbol = "⌘ ";
      hg_branch.symbol = " ";
      java.symbol = " ";
      julia.symbol = " ";
      lua.symbol = " ";
      memory_usage.symbol = " ";
      meson.symbol = "喝 ";
      nim.symbol = " ";
      nix_shell.symbol = " ";
      nodejs.symbol = " ";
      os.symbols = {
        Alpine = " ";
        Amazon = " ";
        Android = " ";
        Arch = " ";
        CentOS = " ";
        Debian = " ";
        DragonFly = " ";
        Emscripten = " ";
        EndeavourOS = " ";
        Fedora = " ";
        FreeBSD = " ";
        Garuda = "﯑ ";
        Gentoo = " ";
        HardenedBSD = "ﲊ ";
        Illumos = " ";
        Linux = " ";
        Macos = " ";
        Manjaro = " ";
        Mariner = " ";
        MidnightBSD = " ";
        Mint = " ";
        NetBSD = " ";
        NixOS = " ";
        OpenBSD = " ";
        openSUSE = " ";
        OracleLinux = " ";
        Pop = " ";
        Raspbian = " ";
        Redhat = " ";
        RedHatEnterprise = " ";
        Redox = " ";
        Solus = "ﴱ ";
        SUSE = " ";
        Ubuntu = " ";
        Unknown = " ";
        Windows = " ";
      };
      package.symbol = " ";
      python.symbol = " ";
      rlang.symbol = "ﳒ ";
      ruby.symbol = " ";
      rust.symbol = " ";
      scala.symbol = " ";
      spack.symbol = "🅢 ";

      # --- Add/Modify module settings for the second line ---
      username = {
        show_always = true;
        format = "[$user]($style)"; # Default format
        style_user = "bold green";
      };

      hostname = {
        ssh_only = false; # Show hostname even if not on SSH
        format = "[$hostname]($style)"; # Default format
        style = "bold blue";
      };

      git_branch = {
        format = "\\([$symbol$branch]($style)\\)"; # Remove 'on' or other prefixes
        style = "bold purple";
      };

      # Directory settings for the second line
      directory = {
          # read_only = " "; # Keep existing read_only symbol if defined - REMOVED TO FIX LINTER ERROR
          home_symbol = "~"; # Use ~ for home directory
          truncation_length = 1; # Example: show last 3 dirs, adjust as needed
          truncate_to_repo = false; # Show path relative to repo root if possible
          format = "[$path]($style)[$read_only]($read_only_style) "; # Add space at the end if needed, or adjust based on surrounding elements
          style = "bold cyan"; # Example style
      };

      # Keep existing character settings
      # character = { ... };

      # Optional: Add status symbols for clarity
      status = {
        symbol = "✓";
        error_symbol = "✗";
        pipestatus = true;
        disabled = false;
      };

      # Optional: Configure cmd_duration display threshold (e.g., only show if > 500ms)
      cmd_duration = {
         min_time = 500; # milliseconds
         show_milliseconds = false;
         disabled = false;
         style = "bold yellow";
      };
    };
  };
}
