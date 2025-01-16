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
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprpanel = {
      url = "github:Jas-SinghFSU/HyprPanel";
    };
    Hyprspace = {
      url = "github:KZDKM/Hyprspace";
    };
    hyprsplit = {
      url = "github:shezdy/hyprsplit";
    };
    nix-ld.url = "github:Mic92/nix-ld";
    nix-ld.inputs.nixpkgs.follows = "nixpkgs";
  };

  # System Configuration
  # Main outputs section defining system configurations, overlays, and home-manager setups
  outputs = { self, nixpkgs, nix-ld, home-manager, rust-overlay, nixos-hardware, xremap, flake-utils, ... }@inputs:
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
          in python;

        # Available Python versions
        pythonVersions = let self = mkPythonBuilders pkgs; in {
          py312 = pkgs.python312;
          # Custom build for specific patch version
          py3122 = self.buildPython {
            version = "3.12.2";
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
          nodePackages = prev.nodePackages // {
            exa-mcp-server = prev.callPackage ./pkgs/nodePackages/exa-mcp-server {};
          };
          
          # Add Python-related functionality
          inherit (mkPythonBuilders prev) buildPython pythonVersions;
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
      mkUserConfig = { name, description, extraGroups ? [], shell ? "fish", ...}: {
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
            inherit inputs nixpkgs hostname username;
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
          currentUser = let 
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
            nix-ld.nixosModules.nix-ld
            (mkSystemOverlays)
            (mkHomeManagerConfig { inherit hostname username; })
            ({ config, pkgs, ... }: {
              assertions = [{
                assertion = builtins.trace "Debug - Checking assertion: currentUser=${currentUser}, username=${username}"
                  (currentUser != "" && currentUser == username);
                message = "Current user (${if currentUser == "" then "unknown" else currentUser}) does not match configured username (${username})";
              }];

              users.users = builtins.listToAttrs (
                builtins.map (userKey: {
                  name = users.${userKey}.name;
                  value = removeAttrs users.${userKey} [ "name" ] // {
                    shell = pkgs.${users.${userKey}.shell};
                  };
                }) enabledUsers
              );
            })
            ./hosts/nixos/${hostname}/nixos.nix
          ];
          specialArgs = {
            inherit nixpkgs inputs hostname username;
          };
        };
    in
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pythonTools = mkPythonBuilders pkgs;

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
            packages = [ pythonTools.pythonVersions.py312 ];
            shellHook = ''
              echo "Welcome to Python ${pythonTools.pythonVersions.py312.version} environment"
            '';
          };

          py3122 = mkPythonShell pythonTools.pythonVersions.py3122;
          py312 = mkPythonShell pythonTools.pythonVersions.py312;
          py311 = mkPythonShell pythonTools.pythonVersions.py311;
        };

        packages = pythonTools.pythonVersions;
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
