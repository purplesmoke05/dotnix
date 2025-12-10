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

  # Keep settings/keybindings for our manual copy flow only. / 手動コピー用に設定とキーバインドを保持。
  vscodeSettings = import ./settings.nix;
  vscodeKeybindings = import ./keybindings.nix;

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
      # Avoid HM-managed symlinked settings; activation writes real files. / HM 管理のシンボリックリンクを避け、activation で実ファイルを書き込む。
      keybindings = lib.mkForce [ ];
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
        # ms-python.python # Moved to marketplace extensions due to hash mismatch
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
          name = "zenkaku";
          publisher = "mosapride";
          version = "0.0.3";
          sha256 = "0abbgg0mjgfy5495ah4iiqf2jck9wjbflvbfwhwll23g0wdazlr5";
        }
        {
          name = "python";
          publisher = "ms-python";
          version = "2025.1.2025012401";
          sha256 = "sha256-uD6NWGD5GyYwd7SeoGsgYEH26NI+hDxCx3f2EhqoOXk=";
        }
      ];
      # Only set userSettings for Linux
      userSettings = lib.mkForce { };
    };
  };

  home.packages = with pkgs; [
    vscode
  ];

  # Copy configuration files directly to avoid read-only symlinks / 読み取り専用シンボリックリンクを避けるため直接コピー
  home.activation = lib.mkIf (isDarwin || isLinux) {
    writeVSCodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "${vscodeConfigDir}"
      $DRY_RUN_CMD rm -f "${vscodeConfigDir}/settings.json" "${vscodeConfigDir}/keybindings.json"
      $DRY_RUN_CMD cp --remove-destination ${beautifyJson (builtins.toJSON vscodeSettings)} "${vscodeConfigDir}/settings.json"
      $DRY_RUN_CMD cp --remove-destination ${beautifyJson (builtins.toJSON vscodeKeybindings)} "${vscodeConfigDir}/keybindings.json"
      $DRY_RUN_CMD chmod 644 "${vscodeConfigDir}/settings.json"
      $DRY_RUN_CMD chmod 644 "${vscodeConfigDir}/keybindings.json"
    '';
  };

  # xdg.configFile."Code/User/settings.json".text = builtins.toJSON (import ./settings.nix);
}
