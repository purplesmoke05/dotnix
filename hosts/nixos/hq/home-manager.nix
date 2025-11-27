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
    ../../../home-manager/mcp-servers/default.nix
  ];

  # Home basics / 基本ホーム設定
  # Set identity and stateVersion. / ユーザー情報と stateVersion。
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "24.11";
  };
  programs.home-manager.enable = true;

  # Enable VRR for FreeSync displays. / FreeSync ディスプレイ向けに VRR を有効化。
  wayland.windowManager.hyprland.settings.monitor = [
    "HDMI-A-1,3440x1440@60,0x0,1,vrr,1"
    "DP-1,1920x1080@240,3440x0,1,vrr,1"
  ];
  wayland.windowManager.hyprland.settings.workspace = [
    /*"1,monitor:HDMI-A-1,default:true"
      "2,monitor:HDMI-A-1"
      "3,monitor:HDMI-A-1"
      "4,monitor:HDMI-A-1"
      "5,monitor:HDMI-A-1"
      "6,monitor:HDMI-A-1"
      "7,monitor:HDMI-A-1"
      "8,monitor:HDMI-A-1"
      "9,monitor:HDMI-A-1"
      "10,monitor:HDMI-A-1"

      "1,monitor:DP-1"
      "2,monitor:DP-1"
      "3,monitor:DP-1"
      "4,monitor:DP-1"
      "5,monitor:DP-1"
      "6,monitor:DP-1"
      "7,monitor:DP-1"
      "8,monitor:DP-1"
      "9,monitor:DP-1"
    "10,monitor:DP-1"*/
  ];
}
