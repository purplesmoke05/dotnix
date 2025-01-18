{pkgs, ...}: let 
  beautifyJson = json:
    pkgs.runCommand "beautified.json" {
      buildInputs = [ pkgs.jq ];
      passAsFile = [ "jsonContent" ];
      jsonContent = json;
    } ''
      cat $jsonContentPath | jq '.' > $out
    '';
in {
  home.packages = with pkgs; [
    code-cursor
  ];

  xdg.configFile."Cursor/User/keybindings.json".source = beautifyJson (builtins.toJSON (import ./vscode/keybindings.nix));
  xdg.configFile."Cursor/User/settings.json".source = beautifyJson (builtins.toJSON (import ./vscode/settings.nix));
}
