{pkgs, ...}: {
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
    };
  };

  # GitHub CLI configuration
  # - Command-line interface for GitHub
  # - Markdown preview extension for documentation
  # - Using Neovim as default editor
  programs.gh = {
    enable = true;
    extensions = with pkgs; [gh-markdown-preview];
    settings = {
      editor = "nvim";
    };
  };
}
