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
    package = pkgs.vscode;
    profiles.default = {
      # Avoid HM-managed symlinked settings; activation writes real files. / HM 管理のシンボリックリンクを避け、activation で実ファイルを書き込む。
      keybindings = lib.mkForce [ ];
      # Only set userSettings for Linux
      userSettings = lib.mkForce { };
    };
  };

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
