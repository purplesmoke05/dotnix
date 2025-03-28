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
    extraGroups = [ "networkmanager" "wheel" "docker"];
    packages = with pkgs; [
    ];
  };

  # Firewall Configuration
  networking.firewall = {
    enable = true;

    # Interface-specific rule configuration
    interfaces = {
      # Rules for wlp5s0 interface (wireless LAN interface)
      "wlp5s0" = {
        allowedUDPPorts = [ 53 67 68 ]; # DNS, DHCP
        allowedTCPPorts = [ 53 ]; # DNS
      };
    };

    # Default rules (applied to all interfaces)
    # Services are exposed only on specific interfaces,
    # while global access is restricted
    allowedUDPPorts = [ ]; # Nothing opened globally
    allowedTCPPorts = [ ]; # Nothing opened globally
  };

  # NVIDIA Driver Configuration
  # Enable NVIDIA driver
  services.xserver.videoDrivers = [ "nvidia" ];

  fileSystems."/mnt/data" = {
    device = "/dev/sda";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  # DHCP Server Configuration
  services.dnsmasq = {
    enable = true;
    settings = {
      interface = [ "docker0" ];
      dhcp-range = "172.17.0.100,172.17.0.200,24h";
      dhcp-option = [
        "option:router,172.17.0.1"
        "option:dns-server,8.8.8.8,8.8.4.4"
      ];
      domain = "local";
      bind-interfaces = true;
      server = [ "8.8.8.8" "8.8.4.4" ];
      log-queries = true;
      log-dhcp = true;
      clear-on-reload = true;
    };
  };

  systemd.services.dnsmasq = {
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
  };
}
