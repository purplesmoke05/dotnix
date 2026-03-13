{ config, pkgs, ... }:
let
  # Mozc config DB / Mozc 設定 DB
  # Build config1.db from textproto and keymap sources. / textproto とキーマップから config1.db を生成する。
  mozcConfigDb =
    let
      mozcProtoRoot = "${pkgs.mozc.src}/src";
    in
    pkgs.runCommand "mozc-config1.db"
      {
        nativeBuildInputs = with pkgs; [
          gawk
          protobuf
        ];
      } ''
      keymap_table="$(
        awk '{
          gsub(/\\/,"\\\\");
          gsub(/"/,"\\\"");
          gsub(/\t/,"\\t");
          printf "%s\\n", $0;
        }' ${./mozc/keymap.tsv}
      )"

      {
        cat ${./mozc/config-base.textproto}
        printf 'custom_keymap_table: "%s"\n' "$keymap_table"
      } > config.textproto

      protoc \
        -I ${mozcProtoRoot} \
        --encode=mozc.config.Config \
        ${mozcProtoRoot}/protocol/config.proto \
        < config.textproto > "$out"
    '';
in
{
  # User packages / ユーザーパッケージ
  # Provide Fcitx5 + Hazkey + Mozc and desktop tooling. / Fcitx5 + Hazkey + Mozc やテーマ関連を揃える。
  home.packages = with pkgs; [
    papirus-icon-theme
    mozc
    fcitx5-hazkey
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
    FCITX_ADDON_DIRS = "${pkgs.qt6Packages.fcitx5-with-addons}/lib/fcitx5:${pkgs.fcitx5-hazkey}/lib/fcitx5:${pkgs.fcitx5-mozc}/lib/fcitx5";
    DISABLE_KWALLET = "1";
    FCITX_LOG_LEVEL = "debug";
    GGML_BACKEND_DIR = "${pkgs.fcitx5-hazkey}/lib/hazkey/libllama/backends";
    HAZKEY_DICTIONARY = "${pkgs.fcitx5-hazkey}/share/hazkey/Dictionary";
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
  # Provide detailed Fcitx5, Hazkey, and Mozc configs. / Fcitx5 と Hazkey と Mozc の詳細設定を提供。
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
        DefaultIM=hazkey

        [Groups/0/Items/0]
        # Name / 名前
        Name=hazkey
        # Layout / レイアウト
        Layout=jp

        [Groups/0/Items/1]
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
        DefaultInputMethod=hazkey
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

    # XIM config / XIM 設定
    # Maintain legacy app compatibility. / 旧来アプリ互換を確保。
    "fcitx5/conf/xim.conf" = {
      force = true;
      text = ''
        UseOnTheSpot=True
      '';
    };

    # Mozc database / Mozc データベース
    # Store Mozc's durable keymap and behavior settings. / Mozc の持続設定とキーマップを保持する。
    "mozc/config1.db" = {
      force = true;
      source = mozcConfigDb;
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
