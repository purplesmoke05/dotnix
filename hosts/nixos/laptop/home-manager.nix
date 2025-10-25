# Home Manager configuration / Home Manager 設定
# Define the laptop user's environment. / ラップトップ向け個人環境を定義。
{ pkgs, username, ... }: {
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
    "eDP-1,1920x1080@60,0x0,1" # Built-in panel 1080p60 / 内蔵ディスプレイ 1920x1080@60
  ];
  # Workspace-to-monitor assignment / ワークスペース割当
  wayland.windowManager.hyprland.settings.workspace = [
    "1,monitor:eDP-1,default:true" # Primary workspace / 主要ワークスペース
    "2,monitor:eDP-1"
    "3,monitor:eDP-1"
    "4,monitor:eDP-1"
    "5,monitor:eDP-1"
    "6,monitor:eDP-1"
    "7,monitor:eDP-1"
    "8,monitor:eDP-1"
    "9,monitor:eDP-1"
    "10,monitor:eDP-1"
  ];

  # Alias HQ host via Tailscale FQDN. / Tailscale FQDN 経由で HQ ホストをエイリアス化。
  programs.ssh.matchBlocks."hq" = {
    hostname = "nixos-hq.tailfdaf8.ts.net";
    user = "purplehaze";
    identityFile = "~/.ssh/id_ed25519";
  };
}
