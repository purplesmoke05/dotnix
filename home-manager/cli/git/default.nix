{ pkgs, ... }: {
  # Git version control configuration
  # - Basic user identity settings
  # - Global Git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "purplesmoke05";
        email = "yosuke.otosu@gmail.com";
      };
      alias = {
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
        default = "current";
        autoSetupRemote = true;
        followTags = true;
      };

      branch.autoSetupMerge = "simple";

      # Default fetch behavior
      fetch = {
        prune = true;
        pruneTags = true;
        all = true; # Consider if this is always desired
      };

      # Pull behavior
      pull = {
        rebase = true;
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
  # - Using Neovim as default editor
  programs.gh = {
    enable = true;
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
