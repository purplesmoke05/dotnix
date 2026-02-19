{ inputs, config, pkgs, username, ... }:

{
  # Hardware configuration / ハードウェア設定
  # Import hardware definitions and tuning modules. / ハードウェア定義と最適化モジュールを取り込む。
  imports = [
    ./hardware-configuration.nix
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
    isNormalUser = true;
    description = "Yosuke Otosu";
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
    trustedInterfaces = [ "wlan-hotspot0" ];
    checkReversePath = "loose";

    # Interface rules / インターフェース別ルール
    interfaces = {
      # wlp5s0 (internal Wi-Fi) / wlp5s0（内蔵 Wi-Fi）
      "wlp5s0" = {
        allowedUDPPorts = [ 53 67 68 ]; # DNS と DHCP / DNS and DHCP
        allowedTCPPorts = [ 53 ]; # DNS / DNS
      };
      # USB AP (hostapd) / USB AP（hostapd）
      "wlan-hotspot0" = {
        allowedUDPPorts = [ 53 67 68 ]; # AdGuard DNS と DHCP / AdGuard DNS and DHCP
        allowedTCPPorts = [ 53 ]; # AdGuard DNS / AdGuard DNS
      };
      # Tailscale VPN / Tailscale VPN
      "tailscale0" = {
        allowedTCPPorts = [ 4000 18789 ]; # LiteLLM Proxy, OpenClaw Gateway
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
  # Disable DNS to avoid AdGuard conflicts. / DNS は AdGuard と競合しないよう無効。
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
    "d /var/lib/litellm 0750 root root -"
    "d /var/lib/litellm/pgdata 0750 root root -"
    "d /var/lib/openclaw 0750 root root -"
    "d /var/lib/openclaw/data 0750 root root -"
    "d /var/lib/openclaw/npm-cache 0750 root root -"
  ];

  # Realtek rtw88_usb tuning / Realtek rtw88_usb 調整
  # Disable USB3 switching and deep power saving. / USB3 切替と深い省電力を無効化。
  boot.extraModprobeConfig = ''
    options rtw88_usb switch_usb_mode=N
    options rtw88_core disable_lps_deep=Y
  '';

  # Secrets management / シークレット管理
  # Decrypt secrets via sops-nix using the host SSH key. / ホスト SSH 鍵で sops-nix による復号を実行。
  sops = {
    defaultSopsFile = ../../../secrets/hq/llm-proxy.env;
    defaultSopsFormat = "dotenv";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets."llm-proxy-env" = { };
    secrets."litellm-db-password" = {
      sopsFile = ../../../secrets/hq/litellm-db-password.env;
      format = "dotenv";
    };
    secrets."openclaw-env" = {
      sopsFile = ../../../secrets/hq/openclaw.env;
      format = "dotenv";
    };
  };

  # LiteLLM Proxy container / LiteLLM Proxy コンテナ
  # Run LiteLLM gateway via Podman with sops-decrypted env and config.yaml. / sops 復号済み env と config.yaml で LiteLLM ゲートウェイを稼働。
  virtualisation.oci-containers = {
    backend = "podman";
    containers.litellm-db = {
      image = "docker.io/library/postgres:16-alpine";
      ports = [ "127.0.0.1:5433:5432" ];
      environment = {
        POSTGRES_DB = "litellm";
        POSTGRES_USER = "litellm";
      };
      environmentFiles = [
        config.sops.secrets."litellm-db-password".path
      ];
      volumes = [
        "/var/lib/litellm/pgdata:/var/lib/postgresql/data"
      ];
    };
    containers.litellm = {
      image = "ghcr.io/berriai/litellm:main-latest";
      dependsOn = [ "litellm-db" ];
      environmentFiles = [
        config.sops.secrets."llm-proxy-env".path
      ];
      volumes = [
        "${./litellm-config.yaml}:/app/config.yaml:ro"
      ];
      extraOptions = [ "--network=host" ];
      cmd = [ "--config" "/app/config.yaml" "--port" "4000" ];
    };
    containers.openclaw = {
      image = "docker.io/library/node:22-bookworm";
      environmentFiles = [
        config.sops.secrets."openclaw-env".path
      ];
      environment = {
        OPENCLAW_CONFIG_PATH = "/app/config/openclaw.json";
      };
      volumes = [
        # 設定ファイル（read-only）
        "${./openclaw-config.json}:/app/config/openclaw.json:ro"
        # ランタイム状態（read-write）
        "/var/lib/openclaw/data:/root/.openclaw"
        # npm キャッシュ永続化（npx 再ダウンロード回避）
        "/var/lib/openclaw/npm-cache:/root/.npm"
      ];
      extraOptions = [ "--network=host" ];
      cmd = [ "npx" "-y" "openclaw@2026.2.17" "gateway" "start" ];
    };
  };

  # Ensure containers start after secrets are decrypted. / シークレット復号後にコンテナを起動。
  systemd.services."podman-litellm" = {
    after = [ "sops-nix.service" "podman-litellm-db.service" ];
    wants = [ "sops-nix.service" ];
  };
  systemd.services."podman-openclaw" = {
    after = [ "sops-nix.service" ];
    wants = [ "sops-nix.service" ];
  };

  # Host-specific system packages. / ホスト専用の追加システムパッケージ。
  environment.systemPackages = with pkgs; [
    gamescope
  ];
}
