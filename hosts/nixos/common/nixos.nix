{ inputs, config, pkgs, hostname, username, /*hyprland, hyprland-protocols,*/ ... }:

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
  boot.kernelParams = [ "nvidia.NVreg_PreserveVideoMemoryAllocations=1" "split_lock_mitigate=0" ];

  # Network Configuration
  # Basic network setup with NetworkManager for connection management
  # - NetworkManager: Handles both wireless and wired connections
  # - Static hostname configuration
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.wireless.userControlled.enable = true;
  hardware.wirelessRegulatoryDatabase = true;

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

  # XDG Desktop Portal Configuration
  # Provides desktop integration for file pickers, screen sharing, etc.
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = [ "gtk" ];
      };
      hyprland = {
        default = [ "hyprland" "gtk" ];
      };
    };
  };

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
    playwright.browsers
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
    jetbrains.rust-rover
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
    # package = hyprland.packages.${pkgs.system}.hyprland;
  };

  # XDG Portal Configuration
  # Configures desktop portals for Wayland/Hyprland
  # - Ensures proper file picker and screen sharing functionality
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = [
          "gtk"
        ];
      };
      hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
      };
    };
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
    enable = true;
    dnssec = "true";
  };
  security.protectKernelImage = false;
  time.hardwareClockInLocalTime = true;

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
      };
    };
  };

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
