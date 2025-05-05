{
  # External Dependencies
  # This section defines all external sources and dependencies required by the system:
  # - nixpkgs: Core package repository (unstable channel)
  # - nixos-hardware: Hardware-specific optimizations and drivers
  # - xremap: Keyboard remapping utility
  # - rust-overlay: Rust toolchain and package overlay
  # - home-manager: User environment management
  # - hyprland utilities: hyprpanel, hyprspace, hyprsplit for window management
  # - flake-utils: Utility functions for flake-based systems
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    xremap.url = "github:xremap/nix-flake";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    hyprpanel = {
      url = "github:Jas-SinghFSU/HyprPanel";
    };
    hyprsplit = {
      url = "github:shezdy/hyprsplit";
    };
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser-flake = {
      url = "github:MarceColl/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    /*
      hyprland = {
      url = "github:hyprwm/Hyprland/v0.48.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.hyprland-protocols.follows = "hyprland-protocols";
      };
      hyprland-protocols = {
      url = "github:hyprwm/hyprland-protocols/v0.6.2";
      inputs.nixpkgs.follows = "nixpkgs";
      };
      xdg-desktop-portal-hyprland = {
      url = "github:hyprwm/xdg-desktop-portal-hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.hyprland-protocols.follows = "hyprland-protocols";
      inputs.hyprland.follows = "hyprland";
    };*/
  };

  # System Configuration
  # Main outputs section defining system configurations, overlays, and home-manager setups
  outputs = { self, nixpkgs, home-manager, rust-overlay, nixos-hardware, xremap, flake-utils, claude-desktop, mcp-servers-nix, zen-browser-flake, ... }@inputs:
    let
      # Python builder utilities
      mkPythonBuilders = pkgs: {
        buildPython = { version, sha256 }:
          let
            python = pkgs.python3Packages.python.overrideAttrs (oldAttrs: rec {
              inherit version;
              src = pkgs.fetchurl {
                url = "https://www.python.org/ftp/python/${version}/Python-${version}.tar.xz";
                inherit sha256;
              };
              passthru = oldAttrs.passthru // {
                inherit version;
                pythonVersion = version;
                sourceVersion = version;
                pythonAtLeast = v: builtins.compareVersions version v >= 0;
                pythonOlder = v: builtins.compareVersions version v < 0;
              };
            });
          in
          python;

        # Available Python versions
        pythonVersions = let self = mkPythonBuilders pkgs; in {
          py312 = pkgs.python312;
          # Custom build for specific patch version
          py3122 = self.buildPython {
            version = "3.12.9";
            sha256 = "0w6qyfhc912xxav9x9pifwca40b4l49vy52wai9j0gc1mhni2a5y";
          };
          py311 = pkgs.python311;
          py310 = pkgs.python310;
        };
      };

      # Package Overlays
      # Custom package overlays including node packages and external overlays
      overlays = {
        default = final: prev: {
          # Add the code-cursor package definition here
          code-cursor =
            let
              pname = "cursor";
              # NOTE: You might want to update the version and hashes periodically
              version = "0.48.7"; # Example version, update if needed

              sources = {
                x86_64-linux = final.fetchurl {
                  url = "https://downloads.cursor.com/production/1d623c4cc1d3bb6e0fe4f1d5434b47b958b05876/linux/x64/Cursor-0.48.7-x86_64.AppImage";
                  hash = "sha256-LxAUhmEM02qCaeUUsHgjv0upAF7eerX+/QiGeKzRY4M=";
                };
                aarch64-linux = final.fetchurl {
                  url = "https://downloads.cursor.com/production/1d623c4cc1d3bb6e0fe4f1d5434b47b958b05876/linux/arm64/Cursor-0.48.7-aarch64.AppImage";
                  hash = "sha256-l1T0jLX7oWjq4KzxO4QniUAjzVbBu4SWA1r5aXGpDS4=";
                };
                x86_64-darwin = final.fetchurl {
                  url = "https://downloads.cursor.com/production/1d623c4cc1d3bb6e0fe4f1d5434b47b958b05876/darwin/x64/Cursor-darwin-x64.dmg";
                  hash = "sha256-h9zcmZRpOcfBRK5Xw/AdY/rwlINEHYiUgpCoGXg6hSY=";
                };
                aarch64-darwin = final.fetchurl {
                  url = "https://downloads.cursor.com/production/1d623c4cc1d3bb6e0fe4f1d5434b47b958b05876/darwin/arm64/Cursor-darwin-arm64.dmg";
                  hash = "sha256-FsXabTXN1Bkn1g4ZkQVqa+sOx4JkSG9c09tp8lAcPKM=";
                };
              };

              src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");

              appimageContents = final.appimageTools.extractType2 {
                inherit pname version src;
              };

              linux = final.appimageTools.wrapType2 {
                inherit pname version src;

                extraPkgs = pkgs: with pkgs; [
                  libsecret
                  xorg.libxshmfence
                  nss
                  xorg.libxkbfile
                  xorg.libX11
                  xorg.libXrandr
                  xorg.libXi
                  gtk3
                  rsync
                ];

                extraInstallCommands = ''
                  ${final.rsync}/bin/rsync -a ${appimageContents}/usr/share $out/ --exclude "*.so"

                  substituteInPlace $out/share/applications/cursor.desktop \
                    --replace "/usr/share/cursor/cursor" "$out/bin/cursor" \
                    --replace "Exec=cursor" "Exec=$out/bin/cursor"

                  mv $out/bin/${pname} $out/bin/${pname}.bin
                  cat > $out/bin/${pname} <<EOF
                  #!/bin/sh
                  exec $out/bin/${pname}.bin --ozone-platform-hint=auto --enable-wayland-ime=true --disable-gpu "$@"
                  EOF
                  chmod +x $out/bin/${pname}
                '';
              };

              darwin = prev.stdenvNoCC.mkDerivation {
                inherit pname version src;
                nativeBuildInputs = [ prev.undmg ];
                sourceRoot = ".";
                installPhase = ''
                  mkdir -p $out/Applications
                  cp -r Cursor.app $out/Applications/
                  mkdir -p $out/bin
                  ln -s "$out/Applications/Cursor.app/Contents/Resources/app/bin/cursor" "$out/bin/cursor"
                '';
              };
            in
            if prev.stdenv.isLinux then linux
            else if prev.stdenv.isDarwin then darwin
            else throw "Unsupported platform";

          # Obsidian X11 mode override
          obsidian = prev.obsidian.overrideAttrs (oldAttrs: rec {
            installPhase = builtins.replaceStrings
              [ "--ozone-platform=wayland" ]
              [ "--enable-features=UseOzonePlatform --ozone-platform=x11" ]
              oldAttrs.installPhase;
          });

          # OpenSSH override with custom patch
          openssh = prev.openssh.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./pkgs/ssh/openssh.patch ];
            doCheck = false;
          });

          # Add Python-related functionality
          inherit (mkPythonBuilders prev) buildPython pythonVersions;

          # Add zen-browser overlay
          zen-browser = zen-browser-flake.packages.${prev.system}.default or zen-browser-flake.packages.${prev.system}.zen-browser; # Try both default and zen-browser names
        };
      };

      # User Configuration
      # System-specific user configurations with environment variable fallbacks
      systemUsers = {
        laptop = {
          primary = let env = builtins.getEnv "LAPTOP_USER"; in
            if env != "" then env else "thehand";
        };
        hq = {
          primary = let env = builtins.getEnv "HQ_USER"; in
            if env != "" then env else "purplehaze";
        };
      };

      # User Template
      # Base configuration template for creating user accounts
      mkUserConfig = { name, description, extraGroups ? [ ], shell ? "fish", ... }: {
        inherit name description extraGroups shell;
        isNormalUser = true;
      };

      # User Generation
      # Function to generate system-specific user definitions
      mkUsers = hostname: {
        primary = mkUserConfig {
          name = systemUsers.${hostname}.primary;
          description = "Yosuke Otosu";
          extraGroups = [ "networkmanager" "wheel" ];
          shell = "fish";
        };
      };

      # Home Manager Configuration Builder
      mkHomeManagerConfig = { hostname, username }: {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          extraSpecialArgs = {
            inherit inputs nixpkgs hostname username mcp-servers-nix;
            userConfig = {
              desktop = true;
              dev = true;
              gaming = true;
            };
          };
          users.${username} = {
            imports = [
              ./hosts/nixos/common/home-manager.nix
              ./hosts/nixos/${hostname}/home-manager.nix
            ];
          };
        };
      };

      # System Overlay Configuration
      mkSystemOverlays = {
        nixpkgs.overlays = [
          (import rust-overlay)
          inputs.hyprpanel.overlay
          self.overlays.default
        ];
      };

      # NixOS System Builder
      mkSystem = { system ? "x86_64-linux", hostname, enabledUsers ? [ "primary" ] }:
        let
          users = mkUsers hostname;
          username = systemUsers.${hostname}.primary;
          currentUser =
            let
              envUser = builtins.getEnv "USER";
              envSudo = builtins.getEnv "SUDO_USER";
            in
            if envSudo != "" then envSudo
            else if envUser != "" then envUser
            else username;
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/nixos/common/nixos.nix
            home-manager.nixosModules.home-manager
            (mkSystemOverlays)
            (mkHomeManagerConfig { inherit hostname username; })
            ({ config, pkgs, ... }: {
              assertions = [{
                assertion = builtins.trace "Debug - Checking assertion: currentUser=${currentUser}, username=${username}"
                  (currentUser != "" && currentUser == username);
                message = "Current user (${if currentUser == "" then "unknown" else currentUser}) does not match configured username (${username})";
              }];

              users.users = builtins.listToAttrs (
                builtins.map
                  (userKey: {
                    name = users.${userKey}.name;
                    value = removeAttrs users.${userKey} [ "name" ] // {
                      shell = pkgs.${users.${userKey}.shell};
                    };
                  })
                  enabledUsers
              );
            })
            ./hosts/nixos/${hostname}/nixos.nix
          ];
          specialArgs = {
            inherit nixpkgs inputs hostname username;
            /*inherit (inputs) hyprland hyprland-protocols;*/
          };
        };
    in
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pythonTools = mkPythonBuilders pkgs;

        mkRustShell = pkgs.mkShell {
          packages = [
            pkgs.openssl
          ];

          shellHook = ''
            echo "Welcome to Rust development environment"
            if test -e rust-toolchain.toml; then
              echo "rust-toolchain.tomlを検出しました"
              rustup toolchain install $(remarshal -i rust-toolchain.toml -if toml -of json | jq -r .toolchain.channel)
            fi
          '';
        };

        pythonPackages = pythonVersion: with pythonVersion.pkgs; [
          playwright
        ];

        mkPythonShell = pythonVersion: pkgs.mkShell {
          packages = [ pythonVersion ]
          ++ (pythonPackages pythonVersion)
          ++ [ pkgs.playwright-driver.browsers ];

          shellHook = ''
            echo "Welcome to Python ${pythonVersion.version} environment"
            export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
            export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
          '';
        };

      in
      {
        devShells = {
          default = pkgs.mkShell {
            buildInputs = [ pythonTools.pythonVersions.py312 pkgs.fish ];
            shellHook = ''
              echo "Welcome to Python ${pythonTools.pythonVersions.py312.version} environment"
              export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
              # Execute fish if not already in fish shell
              if [ -z "$FISH_VERSION" ]; then
                exec ${pkgs.fish}/bin/fish
              fi
            '';
          };

          rust = mkRustShell;
          py3122 = mkPythonShell pythonTools.pythonVersions.py3122;
          py312 = mkPythonShell pythonTools.pythonVersions.py312;
          py311 = mkPythonShell pythonTools.pythonVersions.py311;
        };

        packages = pythonTools.pythonVersions;
        formatter = pkgs.nixpkgs-fmt;
      }
    )) // {
      # Export overlays for external use
      inherit overlays;

      # NixOS System Configurations
      # Define available system configurations for different hosts
      nixosConfigurations = {
        laptop = mkSystem {
          hostname = "laptop";
          enabledUsers = [ "primary" ];
        };
        hq = mkSystem {
          hostname = "hq";
          enabledUsers = [ "primary" ];
        };
      };
    };
}
