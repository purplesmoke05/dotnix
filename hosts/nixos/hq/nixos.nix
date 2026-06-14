{ inputs, config, pkgs, username, ... }:

let
  lib = pkgs.lib;
  sopsAgeKeyFile = "/var/lib/sops-nix/key.txt";
in
{
  # Hardware configuration / ハードウェア設定
  # Import hardware definitions and tuning modules. / ハードウェア定義と最適化モジュールを取り込む。
  imports = [
    ./hardware-configuration.nix
    ./proton-vpn.nix
  ] ++ (with inputs.nixos-hardware.nixosModules; [
    common-cpu-amd
    common-pc-ssd
  ]) ++ [
    inputs.xremap.nixosModules.default
  ];

  # Power management / 電源管理
  # Use TLP and thermald for laptop power/thermal control. / TLP と thermald でノート向け制御。
  services.tlp.enable = true;
  services.thermald.enable = true;
  # User configuration / ユーザー設定
  # Grant network and admin access to primary user. / 主要ユーザーに管理権限を付与。
  users.users.${username} = {
    uid = 1000;
    isNormalUser = true;
    description = "Yosuke Otosu";
    linger = true;
    extraGroups = [ "networkmanager" "wheel" "docker" "i2c" ];
    packages = with pkgs; [
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEnLxrW1BOyt8CREqoEzBaH86LEh6+4rE27Kv+Zl6vU9"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDzfuIp5GmSgUAJFlRxHtCFPwhZ/1Zo3ItoeMgbfIaLw"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDo31UyrkM48T7kLYXfYCIZD0MNNT+bDtKi9Wm1cpvoA thehand@nixos"
    ];
  };

  # Unmanage hotspot Wi-Fi / ホットスポット用 Wi-Fi を NetworkManager 管理から除外
  networking.networkmanager.unmanaged = [
    "interface-name:wlp2s0f0u5"
    "interface-name:wlan-hotspot0"
  ];
  networking.wireless.interfaces = [ "wlp5s0" ];

  hq.protonVpn.enable = true;

  # hostapd access point / hostapd アクセスポイント
  # Store passphrase outside the Nix store. / パスフレーズは平文ファイルに配置（Nix ストア非保存）。
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
        wifi4.capabilities = [ "HT40+" "SHORT-GI-20" "SHORT-GI-40" ];
        networks.wlan-hotspot0 = {
          ssid = "Hotspot";
          authentication = {
            # Prefer WPA2-SHA256 for Realtek 88x2bu / Realtek 88x2bu と互換性確保
            mode = "wpa2-sha256";
            wpaPasswordFile = "/var/lib/hostapd/hotspot.pass";
            # Need WPA3? switch to SAE. / WPA3 が必要なら SAE 系に変更
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

  # Firewall configuration / ファイアウォール設定
  networking.firewall = {
    enable = true;
    checkReversePath = "loose";

    # Interface rules / インターフェース別ルール
    interfaces = {
      # USB AP (hostapd) / USB AP（hostapd）
      "wlan-hotspot0" = {
        allowedUDPPorts = [ 53 67 68 ]; # DNS and DHCP / DNS と DHCP
        allowedTCPPorts = [ 53 ]; # DNS / DNS
      };
    };

    # Default rules / 既定ルール
    # Keep global port exposure closed. / グローバルにはポートを開かない。
    allowedUDPPorts = [ ]; # Global closed / グローバルで閉鎖
    allowedTCPPorts = [ ]; # Global closed / グローバルで閉鎖
  };

  # USB polling / USB ポーリング
  # Fix usbhid at 1000Hz to cut latency. / usbhid を 1000Hz に固定し入力遅延を削減。
  boot.kernelParams = [ "usbhid.jspoll=1" ]; # 1ms interval = 1000Hz / 1ms 間隔

  # AMD driver / AMD ドライバー
  # Use amdgpu for the Radeon board. / Radeon ボード向けに amdgpu ドライバーを使用。
  services.xserver.videoDrivers = [ "amdgpu" ];

  fileSystems."/mnt/data" = {
    device = "/dev/sda";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  # DHCP server / DHCP サーバー
  # Disable DNS to avoid resolver conflicts. / DNS リゾルバとの競合を避けるため DNS は無効。
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
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
          "tag:wlan-hotspot0,option:router,10.43.0.1"
          "tag:wlan-hotspot0,option:dns-server,10.43.0.1"
        ] ++ opt config.virtualisation.docker.enable [
          "tag:docker0,option:router,172.17.0.1"
          "tag:docker0,option:dns-server,172.17.0.1"
        ];
      in
      {
        interface = ifaces;
        # Serve AP subnet (+ docker0 when enabled) / AP サブネットと docker0
        dhcp-range = dhcpRanges;
        # Router/DNS per interface / インターフェースごとのルーター/DNS
        dhcp-option = dhcpOpts;
        # Authoritative mode for fast renewals / 権威モードで更新を確実化
        dhcp-authoritative = true;
        # Track late interfaces / 後から現れるインターフェースに追従
        bind-dynamic = true;
        # DHCP only, disable DNS / DHCP のみに限定
        port = 0;
        domain = "local";
        log-queries = true;
        log-dhcp = true;
        clear-on-reload = true;
      };
  };

  # dnsmasq startup order / dnsmasq 起動順
  # Start after network, plus docker when enabled. / ネットワーク後に開始し、Docker 有効時のみ連鎖。
  systemd.services.dnsmasq.after = [ "network-setup.service" ]
    ++ pkgs.lib.optionals config.virtualisation.docker.enable [ "docker.service" ];

  # NAT for hotspot / ホットスポット向け NAT
  networking.nat = {
    enable = true;
    externalInterface = "enp4s0";
    internalInterfaces = [ "wlan-hotspot0" ];
  };

  # hostapd secret directory / hostapd シークレット用ディレクトリ
  systemd.tmpfiles.rules = [
    # path mode user group age / パス モード ユーザー グループ age
    "d /var/lib/hostapd 0750 root root -"
  ];

  # Realtek rtw88_usb tuning / Realtek rtw88_usb 調整
  # Disable USB3 switching and deep power saving. / USB3 切替と深い省電力を無効化。
  boot.extraModprobeConfig = ''
    options rtw88_usb switch_usb_mode=N
    options rtw88_core disable_lps_deep=Y
  '';

  # Bluetooth adapter policy / Bluetooth アダプター方針
  # Prefer the TP-Link UB500 and keep the flaky onboard Intel controller unavailable. / TP-Link UB500 を優先し、不安定な内蔵 Intel コントローラーを使用不可にする。
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="8087", ATTR{idProduct}=="0aa7", TEST=="authorized", ATTR{authorized}="0"
    ACTION=="add|change", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="2357", ATTR{idProduct}=="0604", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add|change", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="2357", ATTR{idProduct}=="0604", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"
  '';

  systemd.services.hq-bluetooth-adapter-policy = {
    description = "Apply hq Bluetooth adapter policy";
    before = [ "bluetooth.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for device in /sys/bus/usb/devices/*; do
        [ -f "$device/idVendor" ] || continue
        [ -f "$device/idProduct" ] || continue

        vendor="$(cat "$device/idVendor")"
        product="$(cat "$device/idProduct")"

        case "$vendor:$product" in
          8087:0aa7)
            [ -w "$device/authorized" ] && echo 0 > "$device/authorized"
            ;;
          2357:0604)
            [ -w "$device/power/control" ] && echo on > "$device/power/control"
            [ -w "$device/power/autosuspend" ] && echo -1 > "$device/power/autosuspend"
            ;;
        esac
      done
    '';
  };

  # Secrets management / シークレット管理
  # Keep the SOPS identity outside the Nix store. / SOPS identity は Nix store 外に保存。
  sops = {
    age = {
      keyFile = sopsAgeKeyFile;
      sshKeyPaths = [ ];
    };
  };

  # Validate the SOPS age identity before secrets are installed. / secrets 配置前に SOPS age identity を検証。
  system.activationScripts = lib.optionalAttrs (config.sops.secrets != { }) {
    validateSopsAgeKey = {
      deps = [ "users" "groups" ];
      text = ''
        key_file=${lib.escapeShellArg sopsAgeKeyFile}
        pub_file="$key_file.pub"

        if [ ! -f "$key_file" ]; then
          echo "missing SOPS age identity: $key_file" >&2
          exit 1
        fi

        chown root:root "$key_file"
        chmod 0600 "$key_file"

        recipient="$(${pkgs.age}/bin/age-keygen -y "$key_file")"
        case "$recipient" in
          age1pq*) ;;
          *)
            echo "unsupported SOPS age identity: $key_file" >&2
            exit 1
            ;;
        esac

        printf '%s\n' "$recipient" > "$pub_file.tmp"
        chown root:root "$pub_file.tmp"
        chmod 0644 "$pub_file.tmp"
        mv "$pub_file.tmp" "$pub_file"
      '';
    };
    setupSecrets = {
      deps = [ "validateSopsAgeKey" ];
    };
  };

  # Host-specific system packages. / ホスト専用の追加システムパッケージ。
  environment.systemPackages = with pkgs; [
    gamescope
    limux
  ];
}
