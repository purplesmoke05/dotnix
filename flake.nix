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
    # TEMP: Pin nixpkgs to a specific commit that includes the 'kiro' editor package.
    # Intention: revert back to the regular 'nixpkgs-unstable' channel once 'kiro' is available there,
    #            then run: `nix flake lock --update-input nixpkgs`.
    # Reference: https://github.com/NixOS/nixpkgs/blob/5f20293476b594398cbf6476891d7c352515577a/pkgs/by-name/ki/kiro/package.nix
    nixpkgs.url = "github:NixOS/nixpkgs/5f20293476b594398cbf6476891d7c352515577a";
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
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprsplit = {
      url = "github:shezdy/hyprsplit?ref=v0.50.1";
      inputs.hyprland.follows = "hyprland";
    };
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland = {
      url = "github:hyprwm/Hyprland/v0.50.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser-flake = {
      url = "github:MarceColl/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    brew-nix = {
      url = "github:BatteredBunny/brew-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-darwin.follows = "nix-darwin";
      inputs.brew-api.follows = "brew-api";
    };
    brew-api = {
      url = "github:BatteredBunny/brew-api";
      flake = false;
    };
  };

  # System Configuration
  # Main outputs section defining system configurations, overlays, and home-manager setups
  outputs = { self, nixpkgs, home-manager, rust-overlay, nixos-hardware, xremap, flake-utils, claude-desktop, mcp-servers-nix, hyprland, hyprsplit, zen-browser-flake, nix-darwin, brew-nix, ... }@inputs:
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
          py3129 = self.buildPython {
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
        common = final: prev: {
          # Common packages like python, zen-browser
          # OpenSSH override with custom patch - assuming this patch is platform-agnostic or handled correctly by nixpkgs for both
          openssh = prev.openssh.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./pkgs/ssh/openssh.patch ];
            doCheck = false;
          });

          # Add gh-iteration package
          gh-iteration = final.callPackage ./pkgs/gh-iteration { inherit (final) testers; };

          # Add ccmanager package
          ccmanager-base = final.callPackage ./pkgs/ccmanager { };
          ccmanager = final.callPackage ./pkgs/ccmanager-wrapper {
            ccmanager = final.ccmanager-base;
          };

          # Add Python-related functionality
          inherit (mkPythonBuilders prev) buildPython pythonVersions;

          # Add zen-browser overlay
          zen-browser = zen-browser-flake.packages.${prev.system}.default or zen-browser-flake.packages.${prev.system}.zen-browser; # Try both default and zen-browser names

          # Add sui package
          sui = final.callPackage ./pkgs/sui { };
        };

        nixos = final: prev: {
          # NixOS/Linux specific overlays, e.g., Obsidian X11 mode
          obsidian = prev.obsidian.overrideAttrs (oldAttrs: rec {
            installPhase = builtins.replaceStrings
              [ "--ozone-platform=wayland" ]
              [ "--enable-features=UseOzonePlatform --ozone-platform=x11" ]
              oldAttrs.installPhase;
          });

          # Add code-cursor package
          code-cursor = final.callPackage ./pkgs/code-cursor { inherit (final) substituteInPlace; };

          # Claude Code CLI - update to latest version 1.0.70
          claude-code = prev.claude-code.overrideAttrs (oldAttrs: rec {
            version = "1.0.70";
            src = prev.fetchurl {
              url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
              sha256 = "sha256-80bfBwXFbjhr8Wi6xiadoCopvbE6PPcT6yabW1lTV1I=";
            };
          });
        };

        # The 'default' overlay now combines common and nixos specific for convenience if needed elsewhere,
        # or for NixOS configurations that used to refer to 'default'.
        default = final: prev: (self.overlays.common final prev) // (self.overlays.nixos final prev);
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
            inherit (inputs) hyprsplit;
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
          self.overlays.default # This now correctly includes common and nixos specific parts
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
            inherit (inputs) hyprland hyprsplit;
          };
        };

      darwinUser = let env = builtins.getEnv "DARWIN_USER"; in if env != "" then env else "user"; # Default to "user" if not set
      darwinHost = let env = builtins.getEnv "DARWIN_HOST"; in if env != "" then env else "darwin-host"; # Default to "darwin-host" if not set

      # Darwin System Builder
      mkDarwinSystem = { hostname, username, system ? "aarch64-darwin" }: nix-darwin.lib.darwinSystem {
        inherit system;
        pkgs = import nixpkgs {
          inherit system;
          # Apply overlays and allow unfree packages for Darwin as well
          config.allowUnfree = true; # Or manage via nixpkgs.config.allowUnfreePredicate if preferred
          overlays = [
            self.overlays.common
            brew-nix.overlays.default
          ]; # Apply ONLY common overlays for Darwin
        };
        modules = [
          ./hosts/darwin/configuration.nix # Adjusted pag
          home-manager.darwinModules.home-manager
          {
            networking.hostName = hostname;
            users.users.${username}.home = "/Users/${username}";
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = false; # As per original darwin/flake.nix
            home-manager.users.${username} = { pkgs, lib, config, ... }: # pkgs, lib, config are passed by home-manager.darwinModules.home-manager
              import ./hosts/darwin/home-manager.nix { inherit pkgs lib config username; }; # Adjusted path and passed args
            home-manager.backupFileExtension = "backup";
          }
        ];
        specialArgs = {
          inherit inputs nixpkgs home-manager username; # Pass necessary inputs and args
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

        mkSolidityShell = pkgs.mkShell {
          packages = with pkgs; [
            foundry
            solc
            slither-analyzer
          ];

          shellHook = ''
            echo "Welcome to Solidity/Ethereum development environment"
            echo "Available tools:"
            echo "  - forge: Build, test, fuzz, debug and deploy Solidity contracts"
            echo "  - cast: Perform Ethereum RPC calls from the command line"
            echo "  - anvil: Local Ethereum node for development"
            echo "  - chisel: Fast, utilitarian, and verbose Solidity REPL"
            echo "  - solc: Solidity compiler"
            echo "  - slither: Solidity static analyzer"
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
              # Execute fish if not already in fish shell
              echo "Current shell: $SHELL"
              echo "Current shell: $FISH_VERSION"
              if [ -z "$FISH_VERSION" ]; then
                exec ${pkgs.fish}/bin/fish
              fi
            '';
          };

          rust = mkRustShell;
          solidity = mkSolidityShell;
          py3129 = mkPythonShell pythonTools.pythonVersions.py3129;
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

      # Darwin System Configurations
      # Define Darwin configurations if DARWIN_HOST and DARWIN_USER are set
      darwinConfigurations.${darwinHost} = mkDarwinSystem {
        hostname = darwinHost;
        username = darwinUser;
      };
    };
}
