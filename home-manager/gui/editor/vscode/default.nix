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
  programs.vscode = {
    enable = true;
    keybindings = import ./keybindings.nix;
    extensions = with pkgs.vscode-extensions; [
      tuttieee.emacs-mcx
      aaron-bond.better-comments
      streetsidesoftware.code-spell-checker
      ms-vscode-remote.remote-containers
      ms-azuretools.vscode-docker
      mikestead.dotenv
      hediet.vscode-drawio
      tamasfe.even-better-toml
      skyapps.fish-vscode
      github.copilot
      github.copilot-chat
      enkia.tokyo-night
      golang.go
      oderwat.indent-rainbow
      ms-ceintl.vscode-language-pack-ja
      pkief.material-icon-theme
      jnoortheen.nix-ide
      christian-kohler.path-intellisense
      ms-python.python
      ms-python.vscode-pylance
      ms-python.debugpy
      mechatroner.rainbow-csv
      rust-lang.rust-analyzer
      shardulm94.trailing-spaces
      redhat.vscode-yaml
    ];
  };
  
  home.packages = with pkgs; [
    vscode
  ];
  
  xdg.configFile."Code/User/settings.json".text = builtins.toJSON (import ./settings.nix);
}
