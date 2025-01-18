{pkgs, ...}: {
  home.packages = with pkgs; [
    vscode
  ];
  programs.vscode.keybindings = import ./keybindings.nix;
  xdg.configFile."Code/User/settings.json".text = builtins.toJSON (import ./settings.nix);
}
