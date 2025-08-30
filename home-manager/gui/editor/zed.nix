{ pkgs, ... }: {
  # Zed editor package
  home.packages = with pkgs; [
    zed-editor
  ];
}

