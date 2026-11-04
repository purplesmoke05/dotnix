{ pkgs, ... }:
{
  programs.nushell = {
    enable = true;
    # Keep the behavior from before home-manager changed this default to true.
    loadSessionVariables = false;
  };
}
