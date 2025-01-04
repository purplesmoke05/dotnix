{pkgs, ...}: {
  # Git version control configuration
  # - Basic user identity settings
  # - Global Git configuration
  programs.git = {
    enable = true;
    userName = "purplesmoke05";
    userEmail = "yosuke.otosu@gmail.com";
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
