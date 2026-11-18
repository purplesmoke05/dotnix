# Home Manager configuration / Home Manager 設定
# Define the laptop user's environment. / ラップトップ向け個人環境を定義。
{ pkgs, lib, username, ... }: {
  # Module imports / モジュール読み込み
  # Bring in development, CLI, GUI, and Hyprland modules. / 開発・CLI・GUI・Hyprland を統合。
  imports = [
    ../../../home-manager/development/default.nix
    ../../../home-manager/cli/default.nix
    ../../../home-manager/gui/default.nix
    ../../../home-manager/wm/hyprland/default.nix
  ];

  # Home basics / 基本ホーム設定
  # Set identity and stateVersion. / ユーザー情報と stateVersion。
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "24.11";
  };
  programs.home-manager.enable = true;

  # Monitor configuration / モニター設定
  wayland.windowManager.hyprland.settings.monitor = [
    # Built-in panel 1080p60 / 内蔵ディスプレイ 1920x1080@60
    { output = "eDP-1"; mode = "1920x1080@60"; position = "0x0"; scale = "1"; }
  ];
  # Workspace-to-monitor assignment; workspace 1 is the primary one. / ワークスペース割当。1 番を主要ワークスペースにする。
  wayland.windowManager.hyprland.settings.workspace_rule = map
    (n: { workspace = toString n; monitor = "eDP-1"; } // lib.optionalAttrs (n == 1) { default = true; })
    (lib.range 1 10);

  # Alias HQ host via Tailscale FQDN. / Tailscale FQDN 経由で HQ ホストをエイリアス化。
  programs.ssh.matchBlocks = {
    "hq" = {
      hostname = "nixos-hq.tailfdaf8.ts.net";
      user = "purplehaze";
      identityFile = "~/.ssh/id_ed25519";
    };
  };
}
