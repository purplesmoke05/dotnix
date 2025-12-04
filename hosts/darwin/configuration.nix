{ pkgs, username, ... }:
{
  # System packages / システムパッケージ
  environment.systemPackages = with pkgs; [
  ];
  system.primaryUser = username;

  # Nix daemon updates / Nix デーモン更新
  nix.package = pkgs.nix;

  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org" # Home Manager キャッシュ / Home Manager cache
    ];
  };

  ids.gids.nixbld = 350;

  # Shell configuration / シェル設定
  programs.zsh.enable = false;
  programs.fish.enable = true;

  # Allow unfree / 非自由パッケージを許可
  nixpkgs.config.allowUnfree = true;

  # Finder settings / Finder 設定
  system.defaults.finder = {
    # Show all extensions / すべての拡張子を表示
    AppleShowAllExtensions = true;

    # Show hidden files / 隠しファイルを表示
    AppleShowAllFiles = true;

    # Hide desktop icons / デスクトップアイコンを非表示
    CreateDesktop = false;

    # Skip extension change warning / 拡張子変更ダイアログを無効化
    FXEnableExtensionChangeWarning = false;

    # Show path bar / パスバーを表示
    ShowPathbar = true;

    # Show status bar / ステータスバーを表示
    ShowStatusBar = true;
  };

  # Dock settings / Dock 設定
  system.defaults.dock = {
    # Auto-hide Dock / Dock を自動的に隠す
    autohide = false;

    # Hide recents / 最近のアプリを非表示
    show-recents = false;

    # Icon size / アイコンサイズ
    tilesize = 50;

    # Enable magnification / ホバー時に拡大
    magnification = true;

    # Magnified size / 拡大時サイズ
    largesize = 64;

    # Dock position / Dock の位置
    orientation = "left";

    # Minimize effect / 最小化エフェクト
    mineffect = "scale";

    # Disable launch animation / 起動アニメーションを無効化
    launchanim = false;
  };

  # State version / stateVersion
  # Check changelog before bumping. / 互換性維持のため変更時は changelog を確認。
  system.stateVersion = 4;

  # Target platform / 対応プラットフォーム
  nixpkgs.hostPlatform = "aarch64-darwin";

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
    };
    brews = [
      "ethereum"
      "solidity"
    ];
    casks = [
      "wireshark"
      "rectangle"
      "raycast"
      "brave-browser"
    ];
  };

  programs.direnv.enable = true;
}
