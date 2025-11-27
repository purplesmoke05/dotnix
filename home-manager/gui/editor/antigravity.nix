{ pkgs, ... }: {
  # Antigravity IDE package
  home.packages = with pkgs; [
    antigravity
  ];
}
