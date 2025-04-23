{ pkgs, ... }:

{
  # Add alternative CLI tools like zoxide and atuin

  # Fast directory navigation
  programs.zoxide = {
    enable = true;
    # Optional: Add aliases or other zoxide settings if needed
    # enableZshIntegration = true; # Assuming zsh is used, adjust if needed
  };

  # Enhanced shell history search
  programs.atuin = {
    enable = true;
    # Optional: Configure atuin settings if needed
    # settings = {
    #   auto_sync = true;
    # };
  };
}
