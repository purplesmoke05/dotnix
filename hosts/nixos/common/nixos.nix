{ inputs, config, pkgs, hostname, username, hyprland, ... }:

let
  setVictrixPolling = pkgs.writeShellScript "set-victrix-binterval" ''
    shopt -s nullglob
    for iface in /sys$DEVPATH/*:1.*; do
      if [ -d "''${iface}" ]; then
        for ep in 81 02 84 04; do
          path="''${iface}/ep_''${ep}/bInterval"
          if [ -w "''${path}" ]; then
            printf '1' > "''${path}" 2>/dev/null || true
          fi
        done
      fi
    done
  '';
in
{
  # System Boot Configuration / システム起動構成
  # Boot via systemd-boot with xanmod for low-latency desktops. / systemd-boot と xanmod カーネルで低遅延デスクトップ向けに起動を構成。
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod_latest;
  # boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod_stable;
  # boot.kernelPackages = pkgs.linuxPackages_6_11;
  boot.kernelPatches = [ ];
  boot.kernelParams = [
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "split_lock_mitigate=0"
    # USB tuning for gaming latency / ゲーム時の USB レイテンシ対策
    "usbhid.jspoll=1"
    "usbcore.usbfs_memory_mb=256"
    "usbcore.autosuspend=-1"
    "xhci_hcd.quirks=262144"
    "threadirqs"
  ];

  # Sysctl Settings / Sysctl 設定
  boot.kernel.sysctl = {
    "kernel.split_lock_mitigate" = 0;
  };

  # Network Configuration / ネットワーク設定
  # Stabilise connectivity with NetworkManager and mkForce hostname. / NetworkManager と固定 hostname で接続を安定化。
  networking.hostName = pkgs.lib.mkForce hostname;
  networking.networkmanager = {
    enable = true;
    dns = "default"; # Use default for Hotspot compatibility / Hotspot 互換のため既定値を使用
    settings = {
      main = {
        rc-manager = "symlink";
      };
    };
  };
  networking.wireless.userControlled.enable = true;
  hardware.wirelessRegulatoryDatabase = true;

  # AdGuard Home DNS / AdGuard Home で DNS を提供
  networking.nameservers = [ "127.0.0.1" ];

  # NetworkManager Hotspot / NetworkManager ホットスポット設定
  environment.etc."NetworkManager/dnsmasq-shared.d/00-hotspot.conf".text = ''
    # Hotspot settings / ホットスポット設定
    interface=wlp5s0
    bind-interfaces
    listen-address=10.42.0.1
    # Avoid DNS port clash with AdGuard Home / AdGuard Home と競合しないよう DNS ポートを変更
    port=0
    # Provide DHCP only; clients resolve DNS themselves. / DHCP のみ提供し DNS はクライアント任せ
    dhcp-range=10.42.0.10,10.42.0.254,255.255.255.0,12h
    dhcp-option=option:router,10.42.0.1
    dhcp-option=option:dns-server,10.42.0.1,1.1.1.1,8.8.8.8
  '';



  # Localization Settings / ロケール設定
  # Asia/Tokyo と ja_JP.UTF-8 を全面適用。 / Apply Asia/Tokyo timezone and ja_JP.UTF-8 locales system-wide.
  time.timeZone = "Asia/Tokyo";
  i18n.defaultLocale = "ja_JP.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ja_JP.UTF-8";
    LC_IDENTIFICATION = "ja_JP.UTF-8";
    LC_MEASUREMENT = "ja_JP.UTF-8";
    LC_MONETARY = "ja_JP.UTF-8";
    LC_NAME = "ja_JP.UTF-8";
    LC_NUMERIC = "ja_JP.UTF-8";
    LC_PAPER = "ja_JP.UTF-8";
    LC_TELEPHONE = "ja_JP.UTF-8";
    LC_TIME = "ja_JP.UTF-8";
  };

  # Japanese Input Method / 日本語入力
  # Fcitx5 + Mozc を GTK/Qt 双方へ統合。 / Provide Fcitx5 + Mozc integration across GTK and Qt.
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
      libsForQt5.fcitx5-qt
      qt6Packages.fcitx5-qt
    ];
  };

  # Font Configuration / フォント構成
  # Cover Japanese fonts, programmer fonts, and emoji. / 日本語・プログラミング・絵文字を網羅。
  fonts = {
    packages = with pkgs; [
      plemoljp
      rictydiminished-with-firacode
      noto-fonts-cjk-serif
      noto-fonts-cjk-sans
      noto-fonts-emoji
      nerd-fonts.noto
      nerd-fonts.jetbrains-mono
      nerd-fonts.hack
      twemoji-color-font
      migu
    ];
    fontDir.enable = true;
    fontconfig = {
      defaultFonts = {
        serif = [ "PlemolJP" "Noto Serif CJK JP" "Noto Color Emoji" "Twitter Color Emoji" ];
        sansSerif = [ "PlemolJP" "Noto Sans CJK JP" "Noto Color Emoji" "Twitter Color Emoji" ];
        monospace = [ "RictyDiminished-Regular" "PlemolJP Console" "JetBrainsMono Nerd Font" "Noto Color Emoji" "Twitter Color Emoji" ];
        emoji = [ "Noto Color Emoji" "Twitter Color Emoji" ];
      };
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <description>Change default fonts for Steam client</description>
          <match>
            <test name="prgname">
              <string>steamwebhelper</string>
            </test>
            <test name="family" qual="any">
              <string>sans-serif</string>
            </test>
            <edit mode="prepend" name="family">
              <string>Migu 1P</string>
            </edit>
          </match>
        </fontconfig>
      '';
    };
  };

  # Display Server / ディスプレイサーバー
  # Keep a pure Wayland session via GDM and Hyprland. / GDM + Hyprland で純粋な Wayland セッションを維持。
  services.xserver.enable = false;
  services.displayManager.gdm = {
    enable = true;
    wayland = true;
  };
  services.displayManager.defaultSession = "hyprland";
  services.desktopManager.gnome.enable = false;

  # Keyboard Layout / キーボード配列
  # Base JP layout with xremap-driven tweaks. / 日本語配列を基本として xremap で拡張。
  services.xserver.xkb = {
    options = "";
    layout = "jp";
    variant = "";
  };

  # Key Remapping / キーカスタマイズ
  # Define CapsLock-to-Ctrl and Emacs-style bindings. / CapsLock→Ctrl や Emacs 互換操作を定義。
  services.xremap = {
    userName = username;
    serviceMode = "user";
    withWlroots = true;
    debug = false;
    config = {
      keypress_delay_ms = 10;
      modmap = [
        {
          name = "Remap CapsLock to Control";
          remap = {
            CapsLock = "Ctrl_L";
          };
        }
      ];
      keymap = [
        {
          name = "Remap RO to Shift_L-RO";
          remap = {
            KEY_RO = "KEY_LEFTSHIFT-KEY_RO";
          };
        }
        {
          name = "Fix underscore/backslash key (JIS keyboard)";
          remap = {
            # Map the 102nd key to Shift+RO so it emits underscore. / 102番キーをShift+ROに再割当してアンダースコアを出力。
            KEY_102ND = "KEY_LEFTSHIFT-KEY_RO";
          };
        }
        {
          name = "Emacs-style";
          remap = {
            C-h = "KEY_BACKSPACE";
          };
        }
        {
          name = "Emacs-style basic keybindings for Obsidian";
          remap = {
            C-a = "KEY_HOME";
            C-e = "KEY_END";
            C-b = "KEY_LEFT";
            C-f = "KEY_RIGHT";
            C-p = "KEY_UP";
            C-n = "KEY_DOWN";

            C-h = "KEY_BACKSPACE";
            C-d = "KEY_DELETE";

            M-v = "KEY_PAGEUP";
            C-v = "KEY_PAGEDOWN";

            C-w = "C-x";
            M-w = "C-c";
            C-y = "C-v";
          };
          application = {
            only = [ "obsidian" "Obsidian" "obsidian.Obsidian" "Obsidian.obsidian" "Obsidian.Obsidian" ];
          };
        }
      ];
    };
  };

  # Audio & Printing / オーディオと印刷
  # Provide PipeWire audio and CUPS printing. / PipeWire と CUPS でモダンな入出力を構成。
  services.printing.enable = true;
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    # Bluetooth audio profile tuning / Bluetooth オーディオ品質調整
    extraConfig.pipewire."99-quality" = {
      "context.properties" = {
        # Raise default sample rate for fidelity. / 標準サンプルレートを上げて音質を確保。
        "default.clock.rate" = 48000;
        "default.clock.allowed-rates" = [ 44100 48000 88200 96000 ];
      };
    };

    # WirePlumber rules for Bluetooth / Bluetooth 用 WirePlumber 設定
    wireplumber.enable = true;
    wireplumber.configPackages = [
      (pkgs.writeTextDir "share/wireplumber/bluetooth.lua.d/51-bluez-config.lua" ''
        bluez_monitor.properties = {
          ["bluez5.enable-sbc-xq"] = true,
          ["bluez5.enable-msbc"] = true,
          ["bluez5.enable-hw-volume"] = true,
          ["bluez5.codecs"] = "[ sbc sbc_xq aac ldac aptx aptx_hd aptx_ll aptx_ll_duplex faststream faststream_duplex ]",
        }

        bluez_monitor.rules = {
          {
            matches = {
              {
                -- Match all Bluetooth devices / 全 Bluetooth デバイスが対象
                { "device.name", "matches", "bluez_card.*" },
              },
            },
            apply_properties = {
              -- Bluetooth audio quality controls / Bluetooth 音質制御
              ["bluez5.auto-connect"] = "[ a2dp_sink ]",
              ["bluez5.hw-volume"] = "[ a2dp_sink ]",

              -- Prefer high quality codecs / 高音質コーデックを優先
              ["bluez5.a2dp.codec"] = "auto",

              -- SBC codec bitpool / SBC コーデックのビットプール
              ["bluez5.a2dp.sbc.min_bitpool"] = 48,
              ["bluez5.a2dp.sbc.max_bitpool"] = 53,

              -- Avoid fallback to HSP/HFP / HSP/HFP への切替を防止
              ["bluez5.headset-roles"] = "[ ]",
              ["bluez5.profile"] = "a2dp_sink",
              ["bluez5.autoswitch-profile"] = false,

              -- Pin sample rate at 48kHz / 48kHz に固定
              ["audio.rate"] = 48000,
              ["audio.allowed-rates"] = "[ 44100 48000 ]",

              -- Session behaviour / セッションの挙動
              ["node.pause-on-idle"] = false,
              ["session.suspend-timeout-seconds"] = 0,
            },
          },
          {
            matches = {
              {
                -- Shokz OpenRun profile / Shokz OpenRun 用プロファイル
                { "device.name", "matches", "bluez_card.A8_F5_E1_4C_7B_20" },
              },
            },
            apply_properties = {
              -- Force A2DP profile / 必ず A2DP を使用
              ["bluez5.profile"] = "a2dp_sink",
              ["bluez5.autoswitch-profile"] = false,
              ["device.profile"] = "a2dp-sink",

              -- Disable microphone roles / マイク系ロールを無効化
              ["bluez5.headset-roles"] = "[ ]",
              ["bluez5.hfp-enable"] = false,
              ["bluez5.hsp-enable"] = false,

              -- Audio tuning / 音質調整
              ["audio.rate"] = 48000,
              ["node.pause-on-idle"] = false,
            },
          },
        }
      '')
    ];
  };

  # Auto-login / 自動ログイン
  # Enable auto-login with systemd tweaks. / systemd workaround で即ログイン。
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = username;

  # GNOME auto-login workaround / GNOME 自動ログイン対策
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Shell & audio tools / シェルとオーディオ支援ツール
  programs = {
    noisetorch.enable = true;
    fish.enable = true;
  };

  # Virtualization & Containers / 仮想化とコンテナ
  # Use rootless Docker alongside Flatpak. / Rootless Docker と Flatpak を併用。
  virtualisation = {
    docker = {
      enable = false;
      rootless = {
        enable = true;
        setSocketVariable = true;
        daemon.settings = {
          dns = [ "8.8.8.8" "8.8.4.4" ];
        };
      };
      autoPrune.enable = true;
      daemon.settings = {
        dns = [ "8.8.8.8" "8.8.4.4" ];
      };
    };
  };

  services.flatpak.enable = true;

  # System Packages / システムパッケージ
  # Base toolset covering dev, Wayland, and IME support. / 開発・Wayland・IME を含む基本ツール群。
  environment.systemPackages = with pkgs; [
    git
    alacritty
    waybar
    wofi
    swww
    grim
    slurp
    wl-clipboard
    any-nix-shell
    fcitx5-mozc
    fcitx5-gtk
    libsForQt5.fcitx5-qt
    qt6Packages.fcitx5-qt
    qt5.qtbase
    qt6.qtbase
    steam
    unzip
    zip
    p7zip
    unrar
    rar
    file-roller
    # playwright.browsers # Disabled: libjxl build failure / libjxl ビルド失敗のため一時停止
    ghq
    peco
    htop
    obsidian
    gcc
    openssl
    openssl.dev
    pkg-config
    python3Packages.toml
    jq
    remarshal
    gnum4
    gnumake
    # jetbrains.rust-rover # Disabled: jetbrains-jdk-jcef build failure / jetbrains-jdk-jcef が失敗するため停止
    libglvnd
    mesa
    zstd
    zstd.dev
    glibc.dev
    libdrm
    libdrm.dev
    llvmPackages.libclang
    llvmPackages.clang
    zlib.dev
    direnv
    ccmanager
    tailscale
    sui
    dnsmasq # NetworkManager hotspot helper / NetworkManager Hotspot 用
    # Gaming diagnostics / ゲーム用診断ツール
    evtest
    jstest-gtk
    antimicrox
    linuxConsoleTools
  ];

  # nix-ld / nix-ld 設定
  # Provide extra runtimes for foreign binaries. / バイナリ互換性を確保する追加ランタイム。
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      openssl
      systemd
      glibc
      glibc.dev
      glib
      cups.lib
      cups
      nss
      nssTools
      alsa-lib
      dbus
      at-spi2-core
      libdrm
      expat
      xorg.libX11
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
      xorg.libxcb
      mesa
      libxkbcommon
      pango
      cairo
      nspr
      xorg.libXcursor
      xorg.libXi
      gtk3
      gdk-pixbuf
      xorg.libXrender
      freetype
      # Additional runtime libs / 追加ランタイムライブラリ
      flac
      freeglut
      libjpeg
      libpng
      libpng12
      libsamplerate
      libmikmod
      libtheora
      libtiff
      pixman
      speex
      # SDL_image (enable on demand) / SDL_image（必要に応じて有効化）
      # SDL_ttf (enable on demand) / SDL_ttf（必要に応じて有効化）
      # SDL_mixer (enable on demand) / SDL_mixer（必要に応じて有効化）
      # SDL2_ttf (enable on demand) / SDL2_ttf（必要に応じて有効化）
      # SDL2_mixer (enable on demand) / SDL2_mixer（必要に応じて有効化）
      libappindicator-gtk2
      libdbusmenu-gtk2
      libindicator-gtk2
      libcaca
      libcanberra
      libgcrypt
      libvpx
      librsvg
      xorg.libXft
      libvdpau
      libiconv
      llvmPackages.libclang.lib
      clang
      libxcrypt
      libclang
      stdenv.cc.libc.dev
      zlib
      zlib.dev
      pkg-config
      llvmPackages.libclang
      stdenv.cc.cc.lib
      zlib
      zstd
      zstd.dev
      glibc
      libdrm.dev
      stdenv.cc.libc.dev
      glibc.dev
      glibc.out
    ];
  };

  # Hyprland / Hyprland 設定
  # Enable the Wayland-native tiling WM. / Wayland ネイティブのタイル型 WM を有効化。
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = hyprland.packages.${pkgs.system}.hyprland;
  };

  # uinput for hintsd / hintsd 用に uinput を有効化
  hardware.uinput.enable = true;

  # AT-SPI bridge / AT-SPI ブリッジ
  # Required for hintsd accessibility scanning. / hintsd のアクセシビリティ探索に必須。
  services.gnome.at-spi2-core.enable = true;

  # System State Version / システム状態バージョン
  # Maintain compatibility with NixOS 24.11. / NixOS 24.11 と互換維持。
  system.stateVersion = "24.11";

  # Nix Package Manager / Nix パッケージマネージャ
  # Tune flakes and garbage collection settings. / Flakes と GC 設定を最適化。
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      # Build speed tuning / ビルド高速化設定
      max-jobs = "auto";
      cores = 0; # 0 uses all available cores / 0は利用可能な全てのコアを使用
      keep-going = true;
      keep-outputs = true;
      keep-derivations = true;
      # Binary caches / バイナリキャッシュ設定
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://hyprland.cachix.org"
        "https://cuda-maintainers.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
      # Download retries & concurrency / ダウンロード再試行と並列度
      download-attempts = 3;
      connect-timeout = 10;
      stalled-download-timeout = 300;
      http-connections = 0; # 0 means unlimited / 0は無制限
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    nixPath = [
      "nixos=/etc/nixos"
      "nixos-config=/etc/nixos/configuration.nix"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  # Environment Variables / 環境変数
  # Configure IME, Wayland, and build env vars together. / IME・Wayland・ビルド環境の一括設定。
  environment = {
    sessionVariables = {
      XMODIFIERS = "@im=fcitx";
      NIXOS_OZONE_WL = "1";
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "Hyprland";
      FCITX_ADDON_DIRS = "${pkgs.fcitx5-with-addons}/lib/fcitx5:${pkgs.fcitx5-mozc}/lib/fcitx5";
      DISABLE_KWALLET = "1";
      FCITX_LOG_LEVEL = "debug";
      GTK_IM_MODULE = "fcitx";
      QT_IM_MODULE = "fcitx";
      GLFW_IM_MODULE = "fcitx";
      SDL_IM_MODULE = "fcitx";
      SYSTEM_FLAKE_PATH = "$HOME/.nix";
      OPENSSL_DIR = "${pkgs.openssl.dev}";
      OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
      OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
    };
  };
  environment.variables = { };

  # System Security / システムセキュリティ
  # Adjust DNSSEC and dual-boot compatibility. / DNSSEC やデュアルブート互換を調整。
  services.resolved = {
    enable = false; # Avoid NM conflicts / NetworkManager との競合を避ける
  };
  security.protectKernelImage = false;
  time.hardwareClockInLocalTime = true;

  # AdGuard Home / AdGuard Home 設定
  # Provide network-wide ad blocking and DNS service. / 広域広告ブロックと DNS 提供を統合。
  services.adguardhome = {
    enable = true;
    host = "0.0.0.0";
    port = 3000;
    openFirewall = true;
    settings = {
      users = [
        # Default credentials; change immediately. / 既定認証情報。必ず変更すること。
      ];
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        protection_enabled = true;
        filtering_enabled = true;
        # Upstream resolvers / 上流 DNS
        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
          "https://dns.google/dns-query"
          "1.1.1.1"
          "8.8.8.8"
        ];
        # Bootstrap for DoH / DoH 解決用ブートストラップ
        bootstrap_dns = [
          "1.1.1.1"
          "8.8.8.8"
        ];
      };
      filtering = {
        rewrites = [ ];
      };
      # Filter lists / フィルタ一覧
      filters = [
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
          name = "AdGuard DNS filter";
          id = 1;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_7.txt";
          name = "AdGuard Japanese filter";
          id = 7;
        }
        {
          enabled = true;
          url = "https://raw.githubusercontent.com/eEIi0A5L/adblock_filter/master/tamago_filter.txt";
          name = "たまごフィルタ (Tamago Filter)";
          id = 100;
        }
      ];
      # Whitelist rules / ホワイトリスト
      user_rules = [
        # Claude API domains / Claude API 用
        "@@||anthropic.com^"
        "@@||claude.ai^"
        "@@||api.anthropic.com^"
        "@@||console.anthropic.com^"
        # AWS domains for Claude / Claude が利用する AWS
        "@@||amazonaws.com^"
        "@@||cloudfront.net^"
        # Allow all subdomains / サブドメイン全許可
        "@@||*.anthropic.com^"
        "@@||*.claude.ai^"

        # Cursor API domains / Cursor API 用
        "@@||cursor.sh^"
        "@@||*.cursor.sh^"
        "@@||api2.cursor.sh^"
        "@@||cursor.com^"
        "@@||*.cursor.com^"
        "@@||downloads.cursor.com^"
        # GitHub for Cursor / Cursor 更新用 GitHub
        "@@||raw.githubusercontent.com^"
      ];
    };
  };

  # Gaming Support / ゲーミング設定
  # Enable Steam with Remote Play and JP fonts. / Steam を有効化しリモートプレイと日本語フォントを補完。
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };
  nixpkgs.config.packageOverrides = pkgs: {
    steam = pkgs.steam.override {
      extraPkgs = pkgs:
        with pkgs; [
          migu
        ];
    };
  };

  # SSH Server / SSH サーバー設定
  # Restrict access to hotspot and Tailscale with keys only. / 公開鍵のみでホットスポットと Tailscale に限定。
  services.openssh = {
    enable = true;
    settings = {
      # Disable password auth / パスワード認証を無効化
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      # Enforce public key auth / 公開鍵認証のみ許可
      PubkeyAuthentication = true;
      # Disable other authentication / 他方式を無効化
      KbdInteractiveAuthentication = false;
      ChallengeResponseAuthentication = false;
    };
    # Restrict networks / 接続元ネットワークを制限
    # Hotspot: 10.42.0.0/24, Tailscale: 100.64.0.0/10
    extraConfig = ''
      # Default deny / 既定で拒否
      Match Address *,!10.42.0.0/24,!100.64.0.0/10
        DenyUsers *

      # Allow hotspot / ホットスポットを許可
      Match Address 10.42.0.0/24
        AllowUsers ${username}
        PubkeyAuthentication yes

      # Allow Tailscale / Tailscale を許可
      Match Address 100.64.0.0/10
        AllowUsers ${username}
        PubkeyAuthentication yes
    '';
  };

  # Firewall ports / ファイアウォール開放ポート
  networking.firewall.allowedTCPPorts = [
    22 # SSH
    53 # DNS (AdGuard Home)
    3000 # AdGuard Home Web UI
  ];
  networking.firewall.allowedUDPPorts = [
    53 # DNS (AdGuard Home)
  ];

  # Tailscale / Tailscale 設定
  # Enable zero-config VPN access. / ゼロコンフィグ VPN を有効化。
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    # Allow tailscale without sudo / sudo なしで tailscale を許可
    permitCertUid = username;
  };

  # Bluetooth / Bluetooth 設定
  # Enable auto power with full profile support. / 自動起動と全プロファイル対応。
  services.blueman.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
        # Prefer A2DP profile / A2DP プロファイルを優先
        AutoConnect = true;
        # Disable multiprofile to protect quality / 複数プロファイルを無効化し音質を確保
        MultiProfile = "off";
        # Improve stability / 接続安定性を向上
        FastConnectable = true;
      };
      Policy = {
        # Auto-switch to A2DP / 自動で A2DP へ切替
        AutoEnable = true;
      };
    };
  };

  # Disable Bluetooth USB autosuspend / Bluetooth USB autosuspend を無効化
  boot.extraModprobeConfig = ''
    options btusb enable_autosuspend=N
  '';

  # Load xpad early for Victrix Pro BFG / Victrix Pro BFG 用に早期 xpad ロード
  boot.kernelModules = [ "xpad" ];

  # Disable USB autosuspend globally / USB autosuspend を全体で無効化
  powerManagement.powertop.enable = false;

  # Gaming Performance / ゲーム性能最適化
  # Tune controller response and power management. / コントローラー応答と電源管理を調整。

  # CPU performance governor / CPU パフォーマンス設定
  powerManagement.cpuFreqGovernor = "performance"; # Lock CPU to highest frequency / 常時最高クロック

  # GameMode auto tuning / GameMode による自動最適化
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10; # Raise game process priority / ゲームプロセスの優先度を上げる
        inhibit_screensaver = 1; # Disable screensaver / スクリーンセーバーを無効化
      };
      custom = {
        start = "${pkgs.bash}/bin/bash -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'";
        end = "${pkgs.bash}/bin/bash -c 'echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'";
      };
    };
  };

  # Realtime tuning / リアルタイム調整
  # Reduce latency for audio and USB input. / オーディオと USB 入力の遅延を抑制。
  security.pam.loginLimits = [
    { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
    { domain = "@audio"; item = "rtprio"; type = "-"; value = "99"; }
    { domain = "@audio"; item = "nofile"; type = "soft"; value = "99999"; }
    { domain = "@audio"; item = "nofile"; type = "hard"; value = "99999"; }
    # Allow real-time priority for user / ユーザーにリアルタイム優先度を付与
    { domain = username; item = "rtprio"; type = "-"; value = "99"; }
    { domain = username; item = "nice"; type = "-"; value = "-20"; }
  ];

  # udev rules / udev ルール
  # Optimise controllers and Bluetooth handling. / コントローラーと Bluetooth の最適化。
  services.udev.extraRules = ''
    # Disable autosuspend for all USB devices / 全 USB デバイスの autosuspend を無効化
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend}="-1"

    # Generic HID gamepads / 汎用 HID ゲームパッドに適用
    ACTION=="add", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_JOYSTICK}=="1", RUN+="${pkgs.bash}/bin/bash -c 'echo 1 > /sys/module/usbhid/parameters/jspoll 2>/dev/null'"
    ACTION=="add", SUBSYSTEM=="input", KERNEL=="js*", RUN+="${pkgs.bash}/bin/bash -c 'echo 1 > /sys/module/usbhid/parameters/jspoll 2>/dev/null'"

    # Disable USB autosuspend for Intel Bluetooth / Intel Bluetooth の autosuspend を無効化
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0a2b", ATTR{power/control}="on"

    # Force A2DP profile for Bluetooth audio / Bluetooth オーディオで A2DP を強制
    ACTION=="add", SUBSYSTEM=="bluetooth", ENV{DEVTYPE}=="link", RUN+="/bin/sh -c 'sleep 2 && pactl set-card-profile bluez_card.%k a2dp-sink || true'"

    # Victrix Pro BFG controller / Victrix Pro BFG コントローラー
    KERNEL=="hidraw*", ATTRS{idVendor}=="0e6f", TAG+="uaccess", ATTR{power/autosuspend}="-1"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0e6f", ATTRS{idProduct}=="021a", TAG+="uaccess", RUN+="${pkgs.bash}/bin/bash -c 'echo 1 > /sys/module/usbhid/parameters/jspoll 2>/dev/null'"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0e6f", ATTRS{idProduct}=="0217", TAG+="uaccess", RUN+="${pkgs.bash}/bin/bash -c 'echo 1 > /sys/module/usbhid/parameters/jspoll 2>/dev/null'"

    # Victrix-specific latency tweaks / Victrix 向けレイテンシー調整
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0e6f", ATTR{power/autosuspend}="-1"
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0e6f", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0e6f", ATTR{power/wakeup}="enabled"
    # Force 1 ms polling on Victrix endpoints with udev-run script. / udev スクリプトで Victrix のエンドポイントを 1ms ポーリングに設定。
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0e6f", RUN+="${setVictrixPolling}"

    # Xbox-compatible controllers / Xbox 互換コントローラーを最適化
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTR{power/autosuspend}="-1"
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTR{power/control}="on"
  '';

  # File Management / ファイル管理
  # Enable Thunar with GVFS and Tumbler support. / Thunar + GVFS + Tumbler を有効化。
  programs.thunar.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  # NVIDIA Containers / NVIDIA コンテナ
  # Allow GPU passthrough for containers. / コンテナで GPU を使えるようにする。
  hardware.nvidia-container-toolkit.enable = true;
  hardware.nvidia.powerManagement.enable = true;
  hardware.nvidia.open = false;
}
