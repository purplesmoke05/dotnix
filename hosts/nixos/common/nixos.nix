{ inputs, config, pkgs, hostname, username, /*hyprland, hyprland-protocols,*/ ... }:

{
  # System Boot Configuration
  # Configures the boot process using systemd-boot for UEFI systems
  # - systemd-boot: Modern UEFI bootloader
  # - xanmod kernel: Optimized for desktop performance with better scheduling and lower latency
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod_latest;
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod;
  # boot.kernelPackages = pkgs.linuxPackages_6_11;

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
            C-h = "Backspace";
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
            only = ["obsidian" "Obsidian" "obsidian.Obsidian" "Obsidian.obsidian" "Obsidian.Obsidian"];
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
      shellAliases = {
        dev = "nix develop $HOME/.nix#";
        update = "uv run python $HOME/.nix/home-manager/gui/editor/vscode/settings.py && uv run python $HOME/.nix/home-manager/gui/editor/vscode/keybindings.py && sudo -E nixos-rebuild switch --flake .#hq";
      };
      shellInit = ''
        any-nix-shell fish --info-right | source

        # Python version auto-switcher function
        function __check_python_version
          if test -e .python-version
            set -l py_version (cat .python-version | string trim)
            set -l version_dots (string join "" (string split "." $py_version))

            if not test -n "$IN_NIX_SHELL"
              set -l dev_shell "py$version_dots"

              if nix flake show $HOME/.nix --json | jq -e ".devShells.\"x86_64-linux\".$dev_shell" > /dev/null
                echo "Python $py_version環境を有効化します..."
                nix develop $HOME/.nix#$dev_shell
              else
                echo "警告: サポートされていないPythonバージョン: $py_version"
                echo "デフォルトの3.12を使用します"
              end
            end
          end
        end

        # Function to check Rust toolchain
        function __check_rust_toolchain
          if test -e rust-toolchain.toml
            set -l toolchain (remarshal -i rust-toolchain.toml -if toml -of json | jq -r .toolchain.channel)
            if not test -n "$IN_NIX_SHELL"
              echo "Rustプロジェクトを検出しました（toolchain: $toolchain）"
              nix develop $HOME/.nix#rust
            end
          end
        end

        # Directory change handler
        function __on_pwd_change --on-variable PWD
          __auto_nix_develop
          __check_rust_toolchain
          __check_python_version
        end

        # Directory navigation function using peco and ghq
        function peco_ghq
            set -l query (commandline)

            if test -n $query
                set peco_flags --query "$query"
            end

            ghq list --full-path | peco $peco_flags | read recent
            if [ $recent ]
                cd $recent
                commandline -r ""
                commandline -f repaint
            end
        end

        # Function to select and kill processes using peco
        function peco_kill
            set -e proc
            set -l query (commandline)

            if test -n $query
                ps aux | peco --query "$query" | read proc
            else
                ps aux | peco | read proc
            end
            if test -n "$proc"
                set -l pid (echo $proc | awk '{print $2}')
                echo "kill pid: $pid. [$proc]"
                kill $pid
            end
            set -e proc
        end

        # Git add, commit, and push function
        function gish
            # Stage all changes
            git add -A
            # Show status
            git status

            read -l -P "Commit with this content. OK? (y/N): " confirm
            switch $confirm
                case y Y yes Yes YES
                    read -l -P "Input Commit Message: " msg
                    git commit -m "$msg"
                    set -l current_branch (git rev-parse --abbrev-ref HEAD)
                    git push origin $current_branch --force
                case '*'
                    echo "Quit."
            end
        end

        # Create new feature branch from develop
        function girk
            # Switch to develop branch
            git checkout develop
            # Pull latest changes
            git pull origin develop
            # Create and switch to new feature branch
            read -l -P "Input feature branch name: " branch_name
            git checkout -b $branch_name
        end

        # Activate VSCode shell integration
        if test "$TERM_PROGRAM" = "vscode"
            . (code --locate-shell-integration-path fish)
        end

        # Function to check VSCode and activate development environment
        function __check_vscode_and_develop
          if test "$TERM_PROGRAM" = "vscode"
            and not test -n "$IN_NIX_SHELL"
            echo "VSCode detected, activating development environment..."
            dev
          end
        end

        # Auto-activate nix develop when entering directory with flake.nix
        function __auto_nix_develop --on-variable PWD
          if test -n "$IN_NIX_SHELL"
            return
          end

          if test -e flake.nix
            echo "Found flake.nix, activating development environment..."
            nix develop
          end
        end

        # Key binding settings
        bind \cr peco_ghq
        bind \cw peco_kill

        # Execute initialization checks
        __check_vscode_and_develop
        __check_rust_toolchain
      '';
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
        daemon.settings = {
          dns = ["8.8.8.8" "8.8.4.4"];
        };
      };
      autoPrune.enable = true;
      daemon.settings = {
        dns = ["8.8.8.8" "8.8.4.4"];
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
    rustup
    remarshal
    gnum4
    gnumake
    zstd
    llvmPackages.libclang.lib
    clang
    jetbrains.rust-rover
    libclang
    libdrm.dev
    libglvnd
    mesa
    libdrm
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
      zstd
      libiconv
      llvmPackages.libclang.lib
      clang
      libxcrypt
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
  environment.variables = {
    PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig";
    LIBCLANG_PATH="${pkgs.llvmPackages.libclang.lib}/lib";
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

  # NVIDIA Container Support
  # NVIDIA Container Toolkit configuration
  # - Enables GPU support in containers
  # - Required for Docker containers using NVIDIA GPUs
  hardware.nvidia-container-toolkit.enable = true;
}
