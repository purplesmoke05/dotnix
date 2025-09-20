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
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEnLxrW1BOyt8CREqoEzBaH86LEh6+4rE27Kv+Zl6vU9"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDzfuIp5GmSgUAJFlRxHtCFPwhZ/1Zo3ItoeMgbfIaLw"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDo31UyrkM48T7kLYXfYCIZD0MNNT+bDtKi9Wm1cpvoA thehand@nixos"
    ];
  };

  # Unmanage the USB Wi‑Fi by NetworkManager (hostapd will own it)
  networking.networkmanager.unmanaged = [
    "interface-name:wlp2s0f0u5"
    "interface-name:wlan-hotspot0"
  ];

  # hostapd: USB dongle as AP on 2.4GHz, CH6, WPA3-SAE transition (WPA3 + WPA2 fallback)
  # NOTE: Place your passphrase (single line) in the file below. It is read at runtime and not stored in the Nix store.
  systemd.network.links."10-wlan-hotspot0" = {
    matchConfig = { MACAddress = "a8:29:48:3d:af:47"; };
    linkConfig = { Name = "wlan-hotspot0"; };
  };

  services.hostapd = {
    enable = true;
    radios = {
      wlan-hotspot0 = {
        driver = "nl80211";
        band = "5g";
        channel = 36;
        countryCode = "JP";
        networks.wlan-hotspot0 = {
          ssid = "Hotspot";
          authentication = {
            # Use WPA2-PSK(SHA256) prioritizing compatibility with Realtek 88x2bu
            mode = "wpa2-sha256";
            wpaPasswordFile = "/var/lib/hostapd/hotspot.pass";
            # Can revert to WPA3 if needed (wpa3-sae or wpa3-sae-transition)
          };
        };
      };
    };
  };

  systemd.services.hostapd = {
    serviceConfig.ExecStartPre = [
      "${pkgs.iproute2}/bin/ip link set dev wlan-hotspot0 down"
      "${pkgs.iproute2}/bin/ip addr flush dev wlan-hotspot0"
      "${pkgs.iproute2}/bin/ip addr add 10.43.0.1/24 dev wlan-hotspot0"
    ];
  };

  # Firewall Configuration
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "wlan-hotspot0" ];
    checkReversePath = "loose";

    # Interface-specific rule configuration
    interfaces = {
      # Rules for wlp5s0 interface (wireless LAN interface)
      "wlp5s0" = {
        allowedUDPPorts = [ 53 67 68 ]; # DNS, DHCP
        allowedTCPPorts = [ 53 ]; # DNS
      };
      # Rules for USB AP interface (hostapd)
      "wlan-hotspot0" = {
        allowedUDPPorts = [ 53 67 68 ]; # DNS via AdGuard, DHCP
        allowedTCPPorts = [ 53 ]; # DNS via AdGuard
      };
    };

    # Default rules (applied to all interfaces)
    # Services are exposed only on specific interfaces,
    # while global access is restricted
    allowedUDPPorts = [ ]; # Nothing opened globally
    allowedTCPPorts = [ ]; # Nothing opened globally
  };

  # USB Controller Polling Rate Configuration
  # Set maximum polling rate (1000Hz) for gaming controllers
  # This reduces input latency for Victrix Pro BFG and other gaming devices
  boot.kernelParams = [ "usbhid.jspoll=1" ]; # 1ms interval = 1000Hz

  # NVIDIA Driver Configuration
  # Enable NVIDIA driver
  services.xserver.videoDrivers = [ "nvidia" ];

  fileSystems."/mnt/data" = {
    device = "/dev/sda";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  # DHCP Server Configuration (DHCP only; DNS disabled to avoid conflict with AdGuard Home)
  services.dnsmasq = {
    enable = true;
    settings =
      let
        opt = pkgs.lib.optionals;
        ifaces = [ "wlan-hotspot0" ] ++ opt config.virtualisation.docker.enable [ "docker0" ];
        dhcpRanges = [
          "10.43.0.10,10.43.0.254,255.255.255.0,12h"
        ] ++ opt config.virtualisation.docker.enable [
          "172.17.0.100,172.17.0.200,24h"
        ];
        dhcpOpts = [
          "interface:wlan-hotspot0,option:router,10.43.0.1"
          "interface:wlan-hotspot0,option:dns-server,10.43.0.1"
        ] ++ opt config.virtualisation.docker.enable [
          "interface:docker0,option:router,172.17.0.1"
          "interface:docker0,option:dns-server,172.17.0.1"
        ];
      in
      {
        interface = ifaces;
        # Serve the Wi‑Fi AP subnet (+ docker0 も有効時のみ)
        dhcp-range = dhcpRanges;
        # Per-interface router/DNS options (DNS points to this host so AdGuard serves it)
        dhcp-option = dhcpOpts;
        # 当該サブネットの権威サーバとしてふるまい、クライアントの設定更新を確実化
        dhcp-authoritative = true;
        # Bind dynamically so dnsmasq tracks interfaces appearing after service start
        bind-dynamic = true;
        # Only DHCP; disable built-in DNS to avoid port 53 conflicts
        port = 0;
        domain = "local";
        log-queries = true;
        log-dhcp = true;
        clear-on-reload = true;
      };
    };

  # dnsmasq の起動順: ネットワーク初期化後。Docker が有効な場合のみ docker.service を after に追加。
  systemd.services.dnsmasq.after = [ "network-setup.service" ]
    ++ pkgs.lib.optionals config.virtualisation.docker.enable [ "docker.service" ];

  # NAT from the AP subnet toward the wired uplink
  networking.nat = {
    enable = true;
    externalInterface = "enp4s0";
    internalInterfaces = [ "wlan-hotspot0" ];
  };

  # Ensure runtime/persistent directory for hostapd secrets exists
  systemd.tmpfiles.rules = [
    # path mode user group age
    "d /var/lib/hostapd 0750 root root -"
  ];

  # Realtek rtw88_usb module parameter tuning (disable USB3 switching, disable deep power saving)
  boot.extraModprobeConfig = ''
    options rtw88_usb switch_usb_mode=N
    options rtw88_core disable_lps_deep=Y
  '';
}
