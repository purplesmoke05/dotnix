# Home Manager configuration / Home Manager 設定
# Define the laptop user's environment. / ラップトップ向け個人環境を定義。
{ pkgs, username, lib, ... }: {
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

  wayland.windowManager.hyprland.settings = {
    # Place DP ultrawide left and rotate HDMI 2.5K portrait on the right. / DPのウルトラワイドを左、HDMIの2.5Kを右で縦向きに配置。
    monitor = [
      "DP-3,3440x1440@100,0x0,1,transform,0,vrr,1" # Ultrawide on DP-3 left / 左側DP-3のウルトラワイド。
      "HDMI-A-1,2560x1600@120,3440x0,1.25,transform,3,vrr,1" # Portrait 2.5K 16:10 on HDMI-A-1 right with VRR and 1.25x scale / 右側HDMI-A-1の2.5K 16:10縦、VRR有効＋1.25倍スケール。
    ];

    # Pin gamescope to HDMI-A-1 workspace 13 bottom-half. / gamescope を HDMI-A-1 のワークスペース13下半分に固定。
    workspace = [
      "13,monitor:HDMI-A-1"
    ];
    windowrulev2 = lib.mkAfter [
      "workspace 13 silent,class:^(gamescope)$"
      "monitor HDMI-A-1,class:^(gamescope)$"
      "float,class:^(gamescope)$"
      "size 1600 1280,class:^(gamescope)$"
      "move 0 1280,class:^(gamescope)$"
    ];
  };
}
