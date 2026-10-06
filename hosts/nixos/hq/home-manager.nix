# Home Manager configuration / Home Manager 設定
# Define the hq user's environment. / hq 向け個人環境を定義。
{ pkgs, username, lib, ... }:
let
  displays = (import ../../../home-manager/wm/hyprland/display-layout.nix).hq;
in
{
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
  systemd.user.startServices = "sd-switch";

  wayland.windowManager.hyprland.settings = {
    # Place DP ultrawide left and rotate DP 2.5K portrait on the right. / DPのウルトラワイドを左、DPの2.5Kを右で縦向きに配置。
    monitor = [
      "desc:${displays.left},preferred,0x0,1,transform,0,vrr,1"
      "desc:${displays.right},2560x1600@120,auto,1.25,transform,3,vrr,1"
    ];

    # Pin applications to displays without depending on workspace numbering. / ワークスペース番号に依存せず表示先の画面を固定する。
    windowrulev2 = lib.mkAfter [
      "monitor desc:${displays.left},class:^(browser-automation)$"
      "monitor desc:${displays.left},class:^(google-chrome)$,title:(OpenAI|ChatGPT|Phone number required|Check your phone)"

      "monitor desc:${displays.right},class:^(steam)$"
      "monitor desc:${displays.right},class:^(gamescope)$"
      # Keep gamescope windows tiled; ignore client fullscreen requests. / gamescope はタイル表示し、全画面要求は抑止する。
      "suppressevent fullscreen,class:^(gamescope)$"

      "monitor desc:${displays.right},class:^(steam_app_1364780)$"
    ];
  };
}
