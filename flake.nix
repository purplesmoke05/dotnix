{
  # External Dependencies
  # This section defines all external sources and dependencies required by the system:
  # - nixpkgs: Core package repository (unstable channel)
  # - nixos-hardware: Hardware-specific optimizations and drivers
  # - xremap: Keyboard remapping utility
  # - rust-overlay: Rust toolchain and package overlay
  # - home-manager: User environment management
  # - hyprland utilities: hyprpanel, hyprspace, hyprsplit for window management
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    xremap.url = "github:xremap/nix-flake";
    rust-overlay.url = "github:oxalica/rust-overlay";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprpanel = {
      url = "github:Jas-SinghFSU/HyprPanel";
    };
    hyprspace = {
      url = "github:myamusashi/Hyprspace/toml";
    };
    hyprsplit = {
      url = "github:shezdy/hyprsplit";
    };
  };

  # System Configuration
  # Main outputs section defining system configurations, overlays, and home-manager setups
  outputs = { self, nixpkgs, home-manager, rust-overlay, nixos-hardware, xremap, ... }@inputs:
    let
      # Package Overlays
      # Custom package overlays including node packages and external overlays
      overlays = {
        default = final: prev: {
          nodePackages = prev.nodePackages // {
            exa-mcp-server = prev.callPackage ./pkgs/nodePackages/exa-mcp-server {};
          };
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
              ./hosts/common/home-manager.nix
              ./hosts/${hostname}/home-manager.nix
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
            ./hosts/common/nixos.nix
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
                builtins.map (userKey: {
                  name = users.${userKey}.name;
                  value = removeAttrs users.${userKey} [ "name" ] // {
                    shell = pkgs.${users.${userKey}.shell};
                  };
                }) enabledUsers
              );
            })
            ./hosts/${hostname}/nixos.nix
          ];
          specialArgs = {
            inherit nixpkgs inputs hostname username;
          };
        };
    in
    {
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
