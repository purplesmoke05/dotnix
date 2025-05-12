{ pkgs, ... }: {
  # Git version control configuration
  # - Basic user identity settings
  # - Global Git configuration
  programs.git = {
    enable = true;
    userName = "purplesmoke05";
    userEmail = "yosuke.otosu@gmail.com";
    aliases = {
      st = "status";
      co = "checkout";
      gr = "grep";
      df = "diff";
      cm = "commit";
      b = "branch";
      rs = "reset";
      rsh = "reset --hard HEAD";
      ph = "push";
      pl = "pull";
    };
    extraConfig = {
      ghq = {
        root = [
          "~/Projects"
        ];
      };

      # Recommended UI/Sorting settings
      column.ui = "auto";
      branch.sort = "-committerdate";
      tag.sort = "version:refname";

      # Default push behavior
      push = {
        default = "simple";
        autoSetupRemote = true;
        followTags = true;
      };

      # Default fetch behavior
      fetch = {
        prune = true;
        pruneTags = true;
        all = true; # Consider if this is always desired
      };

      # Helper settings
      help.autocorrect = "prompt";
      commit.verbose = true; # Show diff in commit message editor

      # Rerere (Reuse Recorded Resolution) settings
      rerere = {
        enabled = true;
        autoupdate = true;
      };

      # Rebase helper settings
      rebase = {
        autoSquash = true;
        autoStash = true;
        updateRefs = true; # Requires Git >= 2.34
      };
    };
  };

  # GitHub CLI configuration
  # - Command-line interface for GitHub
  # - Markdown preview extension for documentation
  # - Using Neovim as default editor
  programs.gh = {
    enable = true;
    extensions = with pkgs; [
      gh-markdown-preview
      gh-iteration
    ];
    settings = {
      editor = "nvim";
    };
  };

  # Lazygit configuration using the dedicated module
  programs.lazygit = {
    enable = true;
    settings = {
      git = {
        # Example setting - adjust as needed
        overrideGpg = true;
      };
      # Add other lazygit settings here if necessary
    };
  };
}
