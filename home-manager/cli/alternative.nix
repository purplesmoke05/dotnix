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
    enableFishIntegration = false; # Explicitly disable fish integration handled by the module
    # Pass flags to `atuin init fish` command
    flags = [ "--disable-ctrl-r" "--disable-up-arrow" ];
    # Configure atuin settings
    settings = {
      # auto_sync = true;
      # Use attribute set for keybindings instead of configText
      keymap_mode = "emacs"; # Explicitly set keymap mode
      keymap = {
        emacs = {
          # Assuming default Emacs keymap mode. Change to 'vim' if needed.
          # Assign Ctrl+R to "no-op" (no operation) to free it up.
          ctrl_r = "no-op";
          # You can add other keybindings here if needed, for example:
          # page_up = "page_up";
          # page_down = "page_down";
        };
      };
    };
  };
}
