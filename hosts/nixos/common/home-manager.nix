{ config, pkgs, ... }:

{
  # User packages / ユーザーパッケージ
  # Provide Fcitx5 + Mozc and desktop tooling. / Fcitx5 + Mozc やテーマ関連を揃える。
  home.packages = with pkgs; [
    papirus-icon-theme
    mozc
    fcitx5-mozc
    fcitx5-gtk
    libsForQt5.fcitx5-qt
    qt6Packages.fcitx5-qt
    qt6Packages.fcitx5-configtool
    appimage-run
    awscli2
  ];

  # Environment variables / 環境変数
  # Bridge IME into each toolkit. / IME を各ツールキットに橋渡し。
  home.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    NIXOS_OZONE_WL = "1";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";
    FCITX_ADDON_DIRS = "${pkgs.qt6Packages.fcitx5-with-addons}/lib/fcitx5:${pkgs.fcitx5-mozc}/lib/fcitx5";
    DISABLE_KWALLET = "1";
    FCITX_LOG_LEVEL = "debug";
    QT_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
  };

  # Cursor theme / カーソルテーマ
  # Use Adwaita across desktops. / Adwaita を全体で利用。
  home.pointerCursor = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
    x11 = {
      enable = true;
      defaultCursor = "Adwaita";
    };
    gtk.enable = true;
  };

  # Input method config / 入力メソッド設定
  # Provide detailed Fcitx5 and Mozc configs. / Fcitx5 と Mozc の詳細設定を提供。
  xdg.configFile = {
    # Input method profile / 入力メソッドプロファイル
    # Set default layout and IM. / 既定レイアウトと IM を指定。
    "fcitx5/profile" = {
      force = true;
      text = ''
        [Groups/0]
        # Group name / グループ名
        Name=Default
        # Layout / レイアウト
        Default Layout=jp
        # Default input method / 既定 IM
        DefaultIM=mozc

        [Groups/0/Items/0]
        # Name / 名前
        Name=mozc
        # Layout / レイアウト
        Layout=jp

        [GroupOrder]
        0=Default
      '';
    };

    # Fcitx5 global config / Fcitx5 全体設定
    # Control system-wide behaviour. / システム全体の動作を制御。
    "fcitx5/config" = {
      force = true;
      text = ''
        [Hotkey]
        EnumerateKeys=
        TriggerKeys=

        [Behavior]
        DefaultInputMethod=mozc
        ShareInputState=All
      '';
    };

    # Classic UI config / Classic UI 設定
    # Tune look and feel. / ルック&フィールを調整。
    "fcitx5/conf/classicui.conf" = {
      text = ''
        Vertical Candidate List=False
        PerScreenDPI=True
        WheelForPaging=True
        Font="Noto Sans CJK JP 10"
        Theme=default
      '';
    };

    # Mozc key bindings / Mozc キーバインド
    # Toggle IME via Henkan/Muhenkan. / 変換キーで IME を切替。
    "mozc/keymap.tsv" = {
      force = true;
      text = ''
        status	key	command
        DirectInput	Henkan	IMEOn
        Composition	Henkan	IMEOn
        Conversion	Henkan	IMEOn
        Precomposition	Henkan	IMEOn
        DirectInput	Muhenkan	IMEOff
        Composition	Muhenkan	IMEOff
        Conversion	Muhenkan	IMEOff
        Precomposition	Muhenkan	IMEOff
      '';
    };

    # XIM config / XIM 設定
    # Maintain legacy app compatibility. / 旧来アプリ互換を確保。
    "fcitx5/conf/xim.conf" = {
      force = true;
      text = ''
        UseOnTheSpot=True
      '';
    };

    # Mozc database / Mozc データベース
    # Provide preconfigured DB. / 事前設定済み DB を配備。
    "mozc/config1.db" = {
      force = true;
      source = ./mozc/config1.db;
    };

    # Mozc config / Mozc 設定
    # Define detailed behaviour. / 詳細動作を定義。
    "fcitx5/conf/mozc.conf" = {
      force = true;
      text = ''
        InitialMode=Direct
        InputState="Follow Global Configuration"
        Vertical=True
        ExpandMode="On Focus"
        PreeditCursorPositionAtBeginning=False
        ExpandKey=Control+Alt+H
      '';
    };
  };

  # Qt framework / Qt フレームワーク
  # Align Qt with GTK dark theme. / GTK テーマ互換とダークテーマ設定。
  qt = {
    enable = true;
    platformTheme = {
      name = "gtk";
    };
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };

  # Exa MCP service / Exa MCP サービス
  # Start after network and restart on failure. / ネットワーク後に自動起動し失敗時に再起動。

  programs.ssh = {
    enable = true;

    extraConfig = ''
      AddKeysToAgent yes
      ServerAliveInterval 60
    '';

  };

}
