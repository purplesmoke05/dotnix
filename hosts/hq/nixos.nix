{ inputs, config, pkgs, username, ... }:

{
  # Hardware-Specific Configuration
  # Imports hardware configurations and optimizations for laptop
  # - Hardware configuration: Basic hardware setup from nixos-generate-config
  # - AMD CPU optimizations: Power management and performance settings
  # - SSD optimizations: TRIM and disk optimization settings
  # - xremap: Key remapping support for laptop keyboard
  imports = [
    ./hardware-configuration.nix
  ] ++ (with inputs.nixos-hardware.nixosModules; [
    common-cpu-amd
    common-pc-ssd
  ]) ++ [
    inputs.xremap.nixosModules.default
  ];

  # Power Management
  # Laptop-specific power and thermal management
  # - TLP: Advanced power management
  # - thermald: Intel thermal management daemon
  services.tlp.enable = true;
  services.thermald.enable = true;

  # User Configuration
  # Primary user setup with administrative privileges
  # - Network management access
  # - Administrative (wheel) group membership
  # - User-specific package installation
  users.users.${username} = {
    isNormalUser = true;
    description = "Yosuke Otosu";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    ];
  };

  # Firewall Configuration
  # Network security settings (currently disabled)
  # Uncomment and configure as needed:
  # - TCP ports: For specific services
  # - UDP ports: For specific protocols
  # - Global firewall toggle
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # networking.firewall.enable = false;

  # NVIDIA Driver Configuration
  # Enable NVIDIA driver
  services.xserver.videoDrivers = [ "nvidia" ];
}
