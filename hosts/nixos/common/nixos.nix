{ inputs, config, pkgs, hostname, username, hyprland, ... }:

{
  # System Boot Configuration
  # Configures the boot process using systemd-boot for UEFI systems
  # - systemd-boot: Modern UEFI bootloader
  # - xanmod kernel: Optimized for desktop performance with better scheduling and lower latency
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod_latest;
  # boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod_stable;
  # boot.kernelPackages = pkgs.linuxPackages_6_11;
  boot.kernelParams = [
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "split_lock_mitigate=0"
    # ゲームコントローラー用低レイテンシー設定
    "usbhid.jspoll=1" # ゲームパッドのポーリングレートを1ms（1000Hz）に設定
    "usbcore.usbfs_memory_mb=256" # USB転送バッファサイズ増加
    "usbcore.autosuspend=-1" # USB autosuspendを完全に無効化
    "threadirqs" # 割り込みをスレッド化してレイテンシー改善
    "preempt=full" # 完全プリエンプション有効化
    "mitigations=off" # CPU脆弱性緩和機能無効化（パフォーマンス向上）
  ];

  # Network Configuration
  # Basic network setup with NetworkManager for connection management
  # - NetworkManager: Handles both wireless and wired connections
  # - Static hostname configuration
  networking.hostName = "nixos";
  networking.networkmanager = {
    enable = true;
    dns = "default"; # Hotspotのためにデフォルト設定を使用
    settings = {
      main = {
        rc-manager = "symlink";
      };
    };
  };
  networking.wireless.userControlled.enable = true;
  hardware.wirelessRegulatoryDatabase = true;

  # Configure DNS to use AdGuard Home
  networking.nameservers = [ "127.0.0.1" ];

  # NetworkManager shared (Hotspot) mode configuration
  environment.etc."NetworkManager/dnsmasq-shared.d/00-hotspot.conf".text = ''
    # Hotspot用の設定
    interface=wlp5s0
    bind-interfaces
    listen-address=10.42.0.1
    # DNSポートを変更（AdGuard Homeとの競合回避）
    port=0
    # DHCPのみ提供（DNSはクライアント側で設定）
    dhcp-range=10.42.0.10,10.42.0.254,255.255.255.0,12h
    dhcp-option=option:router,10.42.0.1
    dhcp-option=option:dns-server,10.42.0.1,1.1.1.1,8.8.8.8
  '';



  # Localization Settings
  # Complete Japanese language support configuration
  # - Time zone: Asia/Tokyo
  # - Locale: Japanese with UTF-8 encoding
  # - All locale categories set to Japanese
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

  # Japanese Input Method Configuration
  # Fcitx5 setup with Mozc engine for Japanese text input
  # - Fcitx5: Modern input method framework
  # - Mozc: Japanese input engine
  # - Complete GUI integration across GTK and Qt
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

  # Font Configuration
  # Comprehensive font setup for Japanese and programming
  # - Japanese fonts: PlemolJP, Noto CJK, Migu
  # - Programming fonts: JetBrains Mono, Hack
  # - Emoji support and Steam client optimization
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

  # Display Server Configuration
  # Pure Wayland setup with GDM and Hyprland
  # - X11: Disabled for pure Wayland experience
  # - GDM: Wayland-native display manager
  # - Hyprland: Modern Wayland compositor
  services.xserver.enable = false;
  services.displayManager.gdm = {
    enable = true;
    wayland = true;
  };
  services.displayManager.defaultSession = "hyprland";
  services.desktopManager.gnome.enable = false;

  # Keyboard Configuration
  # Japanese layout with custom key remapping
  # - Base layout: Japanese
  # - xremap: Advanced key remapping functionality
  services.xserver.xkb = {
    options = "";
    layout = "jp";
    variant = "";
  };

  # Key Remapping Configuration
  # Custom keyboard modifications using xremap
  # - CapsLock to Control for ergonomic improvement
  # - Emacs-style keybindings system-wide
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
            KEY_102ND = "KEY_BACKSLASH";
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

  # Audio and Printing Services
  # Modern audio stack with PipeWire and CUPS printing
  # - PipeWire: Low-latency audio with compatibility layers
  # - CUPS: Network printing support
  services.printing.enable = true;
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    # High-quality Bluetooth audio configuration
    extraConfig.pipewire."99-quality" = {
      "context.properties" = {
        # Increase default sample rate for better quality
        "default.clock.rate" = 48000;
        "default.clock.allowed-rates" = [ 44100 48000 88200 96000 ];
      };
    };

    # WirePlumber configuration for Bluetooth
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
                -- This matches all Bluetooth devices
                { "device.name", "matches", "bluez_card.*" },
              },
            },
            apply_properties = {
              -- Bluetooth audio quality settings
              ["bluez5.auto-connect"] = "[ a2dp_sink ]",
              ["bluez5.hw-volume"] = "[ a2dp_sink ]",

              -- Force high quality codec if available
              ["bluez5.a2dp.codec"] = "auto",

              -- SBC codec quality (bitpool)
              ["bluez5.a2dp.sbc.min_bitpool"] = 48,
              ["bluez5.a2dp.sbc.max_bitpool"] = 53,

              -- Disable switching to HSP/HFP
              ["bluez5.headset-roles"] = "[ ]",
              ["bluez5.profile"] = "a2dp_sink",
              ["bluez5.autoswitch-profile"] = false,

              -- Force 48kHz sample rate (prevent 16kHz telephone quality)
              ["audio.rate"] = 48000,
              ["audio.allowed-rates"] = "[ 44100 48000 ]",

              -- Session settings
              ["node.pause-on-idle"] = false,
              ["session.suspend-timeout-seconds"] = 0,
            },
          },
          {
            matches = {
              {
                -- OpenRun by Shokz専用設定
                { "device.name", "matches", "bluez_card.A8_F5_E1_4C_7B_20" },
              },
            },
            apply_properties = {
              -- 必ずA2DPを使用
              ["bluez5.profile"] = "a2dp_sink",
              ["bluez5.autoswitch-profile"] = false,
              ["device.profile"] = "a2dp-sink",

              -- マイクロフォンロールを無効化
              ["bluez5.headset-roles"] = "[ ]",
              ["bluez5.hfp-enable"] = false,
              ["bluez5.hsp-enable"] = false,

              -- 音質設定
              ["audio.rate"] = 48000,
              ["node.pause-on-idle"] = false,
            },
          },
        }
      '')
    ];
  };

  # Auto-login Configuration
  # Automatic login setup with systemd workarounds
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = username;

  # GNOME Auto-login Workaround
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Shell and Audio Enhancement Programs
  programs = {
    noisetorch.enable = true;
    fish.enable = true;
  };

  # Virtualization and Container Support
  # Docker and Flatpak configuration
  # - Docker: Rootless container runtime
  # - Flatpak: Additional application distribution
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

  # System Packages
  # Core system utilities and applications
  # - Development tools: Git, VSCode
  # - Wayland utilities: Screenshot, clipboard
  # - Input method and toolkit integration
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
    # playwright.browsers # Temporarily disabled - libjxl build failure
    ghq
    peco
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
    # jetbrains.rust-rover # Temporarily disabled - build failure with jetbrains-jdk-jcef
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
    dnsmasq # NetworkManager Hotspot用
  ];

  # Nix-ld Configuration
  # Enable nix-ld for better compatibility with alien packages
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
      # Other things from runtime
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
      # SDL_image
      # SDL_ttf
      # SDL_mixer
      # SDL2_ttf
      # SDL2_mixer
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

  # Hyprland Configuration
  # Wayland-native tiling window manager
  # - Pure Wayland: No Xwayland support
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = hyprland.packages.${pkgs.system}.hyprland;
  };

  # System State Version
  # NixOS release version for maintaining compatibility
  system.stateVersion = "24.11";

  # Nix Package Manager Configuration
  # Package management and garbage collection settings
  # - Flakes: Modern Nix features
  # - Automatic optimization and cleanup
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      # ビルド高速化のための設定
      max-jobs = "auto";
      cores = 0; # 0は利用可能な全てのコアを使用
      keep-going = true;
      keep-outputs = true;
      keep-derivations = true;
      # バイナリキャッシュの設定
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
      # ダウンロードタイムアウトと並列性の設定
      download-attempts = 3;
      connect-timeout = 10;
      stalled-download-timeout = 300;
      http-connections = 0; # 0は無制限
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

  # Environment Variables
  # System-wide environment configuration
  # - Input method integration
  # - Wayland session settings
  # - Toolkit configurations
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

  # System Security Configuration
  # Security and system integrity settings
  # - DNSSEC: Secure DNS resolution
  # - Hardware clock: Dual-boot compatibility
  services.resolved = {
    enable = false; # Disabled to avoid conflicts with NetworkManager
  };
  security.protectKernelImage = false;
  time.hardwareClockInLocalTime = true;

  # AdGuard Home Configuration
  # Network-wide ad blocking and privacy protection
  # - DNS filtering and ad blocking
  # - Web interface on port 3000
  # - DNS service on port 53
  services.adguardhome = {
    enable = true;
    host = "0.0.0.0";
    port = 3000;
    openFirewall = true;
    settings = {
      users = [
        # Default username: admin
        # Default password: changeme (you should change this after first login)
      ];
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        protection_enabled = true;
        filtering_enabled = true;
        # Upstream DNS servers
        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
          "https://dns.google/dns-query"
          "1.1.1.1"
          "8.8.8.8"
        ];
        # Bootstrap DNS servers for resolving DoH endpoints
        bootstrap_dns = [
          "1.1.1.1"
          "8.8.8.8"
        ];
      };
      filtering = {
        rewrites = [ ];
      };
      # Filter lists (at settings level, not under filtering)
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
      # User rules for whitelist
      user_rules = [
        # Claude API domains
        "@@||anthropic.com^"
        "@@||claude.ai^"
        "@@||api.anthropic.com^"
        "@@||console.anthropic.com^"
        # AWS domains that Claude might use
        "@@||amazonaws.com^"
        "@@||cloudfront.net^"
        # Allow all subdomains
        "@@||*.anthropic.com^"
        "@@||*.claude.ai^"

        # Cursor API domains
        "@@||cursor.sh^"
        "@@||*.cursor.sh^"
        "@@||api2.cursor.sh^"
        "@@||cursor.com^"
        "@@||*.cursor.com^"
        "@@||downloads.cursor.com^"
        # GitHub for Cursor updates
        "@@||raw.githubusercontent.com^"
      ];
    };
  };

  # Gaming Support
  # Steam gaming platform configuration
  # - Remote Play: Network gaming support
  # - Font integration: Japanese font support
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };
  nixpkgs.config.packageOverrides = pkgs: {
    steam = pkgs.steam.override {
      extraPkgs = pkgs:
        with pkgs; [
          migu
        ];
    };
  };

  # SSH Server Configuration
  # Secure SSH access restricted to specific network
  # - Public key authentication only (no password auth)
  # - Access limited to Hotspot network (192.168.XXX.0/24)
  # - Replace XXX with your actual network address
  services.openssh = {
    enable = true;
    settings = {
      # Disable password authentication
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      # Only allow public key authentication
      PubkeyAuthentication = true;
      # Disable other authentication methods
      KbdInteractiveAuthentication = false;
      ChallengeResponseAuthentication = false;
    };
    # Restrict SSH access to specific networks
    # NetworkManager Hotspot default network: 10.42.0.0/24
    # Tailscale network: 100.64.0.0/10
    extraConfig = ''
      # Default: deny all
      Match Address *,!10.42.0.0/24,!100.64.0.0/10
        DenyUsers *

      # Allow from Hotspot network
      Match Address 10.42.0.0/24
        AllowUsers ${username}
        PubkeyAuthentication yes

      # Allow from Tailscale network
      Match Address 100.64.0.0/10
        AllowUsers ${username}
        PubkeyAuthentication yes
    '';
  };

  # Firewall configuration for SSH and AdGuard Home
  networking.firewall.allowedTCPPorts = [
    22 # SSH
    53 # DNS (AdGuard Home)
    3000 # AdGuard Home Web UI
  ];
  networking.firewall.allowedUDPPorts = [
    53 # DNS (AdGuard Home)
  ];

  # Tailscale Configuration
  # Zero-config VPN for secure network access
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    # ユーザーがsudoなしでtailscaleコマンドを使えるようにする
    permitCertUid = username;
  };

  # Bluetooth Configuration
  # Wireless device support
  # - Auto-power on boot
  # - All profiles enabled
  services.blueman.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
        # A2DPプロファイルを優先
        AutoConnect = true;
        # マルチプロファイル接続を無効化（音質向上のため）
        MultiProfile = "off";
        # 接続の安定性向上
        FastConnectable = true;
      };
      Policy = {
        # 自動的にA2DPプロファイルに切り替える
        AutoEnable = true;
      };
    };
  };

  # Bluetooth USB autosuspendを無効化（接続安定性のため）
  boot.extraModprobeConfig = ''
    options btusb enable_autosuspend=N
    # Force xpad driver for better polling rate support
    options xpad quirks=0x0e6f:0x021a:0x100
  '';

  # Force load xpad driver before usbhid for Victrix Pro BFG
  boot.kernelModules = [ "xpad" ];

  # USB autosuspendを完全に無効化
  powerManagement.powertop.enable = false;

  # Gaming Performance Optimizations
  # ゲームコントローラーのレスポンス性能向上設定

  # CPUパフォーマンス設定
  powerManagement.cpuFreqGovernor = "performance"; # CPU常時最高クロック

  # ゲームモード（自動的にゲームのパフォーマンスを最適化）
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10; # ゲームプロセスの優先度を上げる
        inhibit_screensaver = 1; # スクリーンセーバー無効化
      };
      custom = {
        start = "${pkgs.bash}/bin/bash -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'";
        end = "${pkgs.bash}/bin/bash -c 'echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'";
      };
    };
  };

  # リアルタイムカーネルの設定（オーディオとUSB入力のレイテンシー削減）
  security.pam.loginLimits = [
    { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
    { domain = "@audio"; item = "rtprio"; type = "-"; value = "99"; }
    { domain = "@audio"; item = "nofile"; type = "soft"; value = "99999"; }
    { domain = "@audio"; item = "nofile"; type = "hard"; value = "99999"; }
    # ユーザーにリアルタイム優先度を許可
    { domain = username; item = "rtprio"; type = "-"; value = "99"; }
    { domain = username; item = "nice"; type = "-"; value = "-20"; }
  ];

  # udevルール：コントローラー接続時の最適化とBluetooth設定
  services.udev.extraRules = ''
    # 全USBデバイスのautosuspendを無効化
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend}="-1"

    # Disable USB autosuspend for Intel Bluetooth
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0a2b", ATTR{power/control}="on"

    # Force A2DP profile for Bluetooth audio devices
    ACTION=="add", SUBSYSTEM=="bluetooth", ENV{DEVTYPE}=="link", RUN+="/bin/sh -c 'sleep 2 && pactl set-card-profile bluez_card.%k a2dp-sink || true'"

    # Victrix Pro BFG Controller (Performance Designed Products)
    KERNEL=="hidraw*", ATTRS{idVendor}=="0e6f", TAG+="uaccess"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0e6f", ATTRS{idProduct}=="021a", TAG+="uaccess"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0e6f", ATTRS{idProduct}=="0217", TAG+="uaccess"

    # Victrix Pro BFG特定の設定（レイテンシー改善）
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0e6f", ATTR{power/autosuspend}="-1"
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0e6f", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0e6f", ATTR{power/wakeup}="enabled"

    # Xbox互換コントローラー全般の最適化
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTR{power/autosuspend}="-1"
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTR{power/control}="on"
  '';

  # File Management
  # File manager and support services
  # - Thunar: Main file manager
  # - GVFS: Virtual filesystem support
  # - Tumbler: Thumbnail generation
  programs.thunar.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  # NVIDIA Container Support
  # NVIDIA Container Toolkit configuration
  # - Enables GPU support in containers
  # - Required for Docker containers using NVIDIA GPUs
  hardware.nvidia-container-toolkit.enable = true;
  hardware.nvidia.powerManagement.enable = true;
  hardware.nvidia.open = false;
}
