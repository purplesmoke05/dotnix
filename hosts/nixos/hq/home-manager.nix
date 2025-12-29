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
    # Place DP ultrawide left and rotate DP 2.5K portrait on the right. / DPのウルトラワイドを左、DPの2.5Kを右で縦向きに配置。
    monitor = [
      "DP-3,preferred,0x0,1,transform,0,vrr,1" # Ultrawide on DP-3 left / 左側DP-3のウルトラワイド。
      "DP-2,2560x1600@120,auto,1.25,transform,3,vrr,1" # Portrait 2.5K 16:10 on DP-2 right with VRR and 1.25x scale / 右側DP-2の2.5K 16:10縦、VRR有効＋1.25倍スケール。
    ];

    # Pin gamescope to DP-2 workspace 3 fullscreen. / gamescope を DP-2 のワークスペース3でフルスクリーン。
    workspace = [
      "3,monitor:DP-2"
    ];
    windowrulev2 = lib.mkAfter [
      "workspace 3 silent,class:^(gamescope)$"
      "monitor DP-2,class:^(gamescope)$"
      "fullscreen,class:^(gamescope)$"

      # Pin Street Fighter 6 to DP-2 workspace 3. / Street Fighter 6 を DP-2 のワークスペース3に固定。
      "workspace 3 silent,class:^(steam_app_1364780)$"
      "monitor DP-2,class:^(steam_app_1364780)$"
    ];
  };
}
