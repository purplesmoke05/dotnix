{ inputs, config, pkgs, hostname, username, ... }:

{
  # System Boot Configuration
  # Configures the boot process using systemd-boot for UEFI systems
  # - systemd-boot: Modern UEFI bootloader
  # - xanmod kernel: Optimized for desktop performance with better scheduling and lower latency
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod_latest;

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
        serif = ["PlemolJP" "Noto Serif CJK JP" "Noto Color Emoji" "Twitter Color Emoji"];
        sansSerif = ["PlemolJP" "Noto Sans CJK JP" "Noto Color Emoji" "Twitter Color Emoji"];
        monospace = ["RictyDiminished-Regular" "PlemolJP Console" "JetBrainsMono Nerd Font" "Noto Color Emoji" "Twitter Color Emoji"];
        emoji = ["Noto Color Emoji" "Twitter Color Emoji"];
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
  services.xserver.displayManager.gdm = {
    enable = true;
    wayland = true;
  };
  services.displayManager.defaultSession = "hyprland";
  services.xserver.desktopManager.gnome.enable = false;

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
    serviceMode = "system";
    config = {
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
          name = "Emacs-style backspace binding";
          remap = {
            C-h = "Backspace";
          };
          application = {
            not = [];
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
    fish = {
      enable = true;
    };
    noisetorch.enable = true;
  };

  # Virtualization and Container Support
  # Docker and Flatpak configuration
  # - Docker: Rootless container runtime
  # - Flatpak: Additional application distribution
  virtualisation = {
    docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
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
    code-cursor
    waybar
    wofi
    dunst
    swww
    grim
    slurp
    wl-clipboard
    fcitx5-mozc
    fcitx5-gtk
    libsForQt5.fcitx5-qt
    qt6Packages.fcitx5-qt
    qt5.qtbase
    qt6.qtbase
    vscode
    steam
    unzip
    zip
    p7zip
    unrar
    rar
    file-roller
  ];

  # Hyprland Configuration  
  # Wayland-native tiling window manager
  # - Pure Wayland: No Xwayland support
  programs.hyprland = {
    enable = true;
    xwayland.enable = false;
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
      experimental-features = ["nix-command" "flakes"];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
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
    };
  };

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
}