{ pkgs, config, lib, ... }:
let
  beautifyJson = json:
    pkgs.runCommand "beautified.json"
      {
        buildInputs = [ pkgs.jq ];
        passAsFile = [ "jsonContent" ];
        jsonContent = json;
      } ''
      cat $jsonContentPath | jq '.' > $out
    '';

  # Platform detection
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;

  # VS Code configuration directory path based on platform
  vscodeConfigDir =
    if isDarwin then
      "${config.home.homeDirectory}/Library/Application Support/Code/User"
    else
      "${config.home.homeDirectory}/.config/Code/User";
in
{
  programs.vscode = {
    enable = true;
    profiles.default = {
      keybindings = if isLinux then import ./keybindings.nix else [ ];
      extensions = with pkgs.vscode-extensions; [
        bbenoist.nix
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
        shardulm94.trailing-spaces
        redhat.vscode-yaml
        catppuccin.catppuccin-vsc
      ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "cform";
          publisher = "aws-scripting-guy";
          version = "0.0.24";
          sha256 = "X3Om8uB94Va/uABnZhzm2ATbqj3wzqt/s2Z844lZcmU=";
        }
        {
          name = "jumpy2";
          publisher = "davidlgoldberg";
          version = "1.7.0";
          sha256 = "1j668ias08jkkz3v1fnljxphhkpgy0imbii2s9i0db390c07j1qf";
        }
        {
          name = "roo-cline";
          publisher = "rooveterinaryinc";
          version = "3.1.6";
          sha256 = "19v27pispwqnsfjiimyka1gfqlxmpwl05ja3iv3c035wwj0v985c";
        }
        {
          name = "zenkaku";
          publisher = "mosapride";
          version = "0.0.3";
          sha256 = "0abbgg0mjgfy5495ah4iiqf2jck9wjbflvbfwhwll23g0wdazlr5";
        }
      ];
      # Only set userSettings for Linux
      userSettings = if isLinux then import ./settings.nix else { };
    };
  };

  home.packages = with pkgs; [
    vscode
  ];

  # For macOS: Use home.activation to copy configuration files directly
  home.activation = lib.mkIf isDarwin {
    writeVSCodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p ${vscodeConfigDir}
      $DRY_RUN_CMD cp ${beautifyJson (builtins.toJSON (import ./settings.nix))} ${vscodeConfigDir}/settings.json
      $DRY_RUN_CMD cp ${beautifyJson (builtins.toJSON (import ./keybindings.nix))} ${vscodeConfigDir}/keybindings.json
      $DRY_RUN_CMD chmod 644 ${vscodeConfigDir}/settings.json
      $DRY_RUN_CMD chmod 644 ${vscodeConfigDir}/keybindings.json
    '';
  };

  # xdg.configFile."Code/User/settings.json".text = builtins.toJSON (import ./settings.nix);
}
