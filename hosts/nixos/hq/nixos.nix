{ inputs, config, pkgs, username, ... }:

let
  lib = pkgs.lib;

  # OpenClaw egress routing knobs. / OpenClaw の外向き経路切替設定。
  tailscaleSidecar = {
    enable = true;
    containerName = "tailscale-network";
    # Use an advertised exit node identifier. / 広告済み exit node の識別子を指定。
    exitNode = "oci-micro-tokyo";
    allowLanAccess = true;
    stateDir = "/mnt/data/openclaw/tailscale";
  };

  tailscaleSocksProxy = {
    enable = tailscaleSidecar.enable;
    containerName = "tailscale-socks-proxy";
    image = "localhost/tailscale-socks-proxy:latest";
    listenPort = 1080;
  };

  tailscaleForwardSlots = {
    slot1 = {
      containerName = "tailscale-forward-slot1";
      listenPort = 1081;
      remoteHost = "100.98.97.41";
      remotePort = 11081;
    };
    slot2 = {
      containerName = "tailscale-forward-slot2";
      listenPort = 1082;
      remoteHost = "100.98.97.41";
      remotePort = 11082;
    };
    slot3 = {
      containerName = "tailscale-forward-slot3";
      listenPort = 1083;
      remoteHost = "100.98.97.41";
      remotePort = 11083;
    };
  };

  # Local SOCKS5 image for the Tailscale sidecar namespace. / Tailscale サイドカー名前空間向けのローカル SOCKS5 イメージ。
  tailscaleSocksProxyImage = pkgs.dockerTools.streamLayeredImage {
    name = "localhost/tailscale-socks-proxy";
    tag = "latest";
    contents = [
      pkgs.microsocks
    ];
    config = {
      Entrypoint = [ "${pkgs.microsocks}/bin/microsocks" ];
    };
  };

  tailscaleTcpForwarderImage = pkgs.dockerTools.streamLayeredImage {
    name = "localhost/tailscale-tcp-forwarder";
    tag = "latest";
    contents = [
      pkgs.socat
    ];
    config = {
      Entrypoint = [ "${pkgs.socat}/bin/socat" ];
    };
  };

  tailscaleForwardSlotContainers = lib.mapAttrs'
    (_: forward:
      lib.nameValuePair forward.containerName {
        image = "localhost/tailscale-tcp-forwarder:latest";
        imageStream = tailscaleTcpForwarderImage;
        pull = "never";
        dependsOn = [ tailscaleSidecar.containerName ];
        podman = {
          user = username;
        };
        cmd = [
          "-d"
          "-d"
          "TCP-LISTEN:${toString forward.listenPort},bind=0.0.0.0,reuseaddr,fork"
          "TCP:${forward.remoteHost}:${toString forward.remotePort}"
        ];
        extraOptions = [ "--network=container:${tailscaleSidecar.containerName}" ];
      }
    )
    tailscaleForwardSlots;

  openclawNetworkMode =
    if tailscaleSidecar.enable then
      "container:${tailscaleSidecar.containerName}"
    else
      "host";

  tailscaleSidecarExtraArgs = lib.concatStringsSep " " [
    "--accept-dns=false"
    "--accept-routes=true"
  ];

  # Set exit node after tailscale connects (node names need control plane). / 接続後に exit node を設定（ノード名は制御サーバーが必要）。
  tailscaleSidecarPostStart = lib.optionalString (tailscaleSidecar.exitNode != null) ''
    timeout=60; elapsed=0
    until ${pkgs.podman}/bin/podman exec ${tailscaleSidecar.containerName} tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -e '.BackendState == "Running"' >/dev/null 2>&1; do
      sleep 2
      elapsed=$((elapsed + 2))
      if [ "$elapsed" -ge "$timeout" ]; then
        echo "tailscale-set-exit-node: timed out waiting for tailscale to connect" >&2
        exit 1
      fi
    done
    ${pkgs.podman}/bin/podman exec ${tailscaleSidecar.containerName} tailscale set --exit-node=${tailscaleSidecar.exitNode}${lib.optionalString tailscaleSidecar.allowLanAccess " --exit-node-allow-lan-access=true"}
  '';

  cloudflareDnsServers = [
    "1.1.1.1"
    "1.0.0.1"
    "2606:4700:4700::1111"
    "2606:4700:4700::1001"
  ];

  tailscaleSidecarDnsExtraOptions = map (server: "--dns=${server}") cloudflareDnsServers;
  tailscaleSidecarPublishedPorts = [
    "127.0.0.1:2455:2455"
    "127.0.0.1:1455:1455"
    "127.0.0.1:18789:18789"
  ] ++ lib.optionals tailscaleSocksProxy.enable [
    "127.0.0.1:${toString tailscaleSocksProxy.listenPort}:${toString tailscaleSocksProxy.listenPort}"
  ] ++ lib.optionals tailscaleSidecar.enable (
    lib.mapAttrsToList
      (_: forward:
        "127.0.0.1:${toString forward.listenPort}:${toString forward.listenPort}"
      )
      tailscaleForwardSlots
  );

  openclawExtraOptions = [ "--network=${openclawNetworkMode}" ];
  openclawGatewayPkg = "openclaw@2026.3.24";

  codexLbExtraOptions = [
    "--pull=missing"
    "--userns=keep-id"
  ] ++ lib.optionals tailscaleSidecar.enable [ "--network=container:${tailscaleSidecar.containerName}" ];
in
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
      # USB AP (hostapd) / USB AP（hostapd）
      "wlan-hotspot0" = {
        allowedUDPPorts = [ 53 67 68 ]; # AdGuard DNS と DHCP / AdGuard DNS and DHCP
        allowedTCPPorts = [ 53 ]; # AdGuard DNS / AdGuard DNS
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
    "d /var/lib/codex-lb 0750 1000 1000 -"
    "d /mnt/data/openclaw 0750 ${username} users -"
    "d /mnt/data/openclaw/root 0750 ${username} users -"
  ] ++ lib.optionals tailscaleSidecar.enable [
    "d /mnt/data/openclaw/tailscale 0750 ${username} users -"
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
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets."openclaw-env" = {
      sopsFile = ../../../secrets/hq/openclaw.env;
      format = "dotenv";
      owner = username;
      group = "users";
      mode = "0400";
    };
    secrets."tailscale-env" = {
      sopsFile = ../../../secrets/hq/tailscale.env;
      format = "dotenv";
      owner = username;
      group = "users";
      mode = "0400";
    };
    secrets."codex-lb-env" = {
      sopsFile = ../../../secrets/hq/codex-lb.env;
      format = "dotenv";
      owner = username;
      group = "users";
      mode = "0400";
    };
  };

  # Application containers / アプリケーションコンテナ
  # Run user-facing services with Podman and sops-managed env files. / Podman と sops 管理の env ファイルでユーザー向けサービスを稼働。
  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      openclaw = {
        image = "docker.io/library/node:22-trixie";
        dependsOn = lib.optionals tailscaleSidecar.enable [ tailscaleSidecar.containerName ];
        podman = {
          user = username;
        };
        environmentFiles = [
          config.sops.secrets."openclaw-env".path
        ];
        environment = {
          OPENCLAW_SKIP_SERVICE_CHECK = "true";
          OPENCLAW_STATE_DIR = "/root/.openclaw";
          NODE_OPTIONS = "--dns-result-order=ipv4first";
          NPM_CONFIG_PREFIX = "/root/.npm-global";
          PATH = "/root/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";
        };
        volumes = [
          "/mnt/data/openclaw/root:/root"
        ];
        extraOptions = openclawExtraOptions;
        cmd = [
          "sh"
          "-lc"
          ''
            test -f /root/.openclaw/openclaw.json || { echo 'missing openclaw.json'; exit 1; }
            if ! command -v jq >/dev/null 2>&1; then
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -qq
              apt-get install -y -qq jq
            fi
            exec npx -y ${openclawGatewayPkg} gateway
          ''
        ];
      };
      codex-lb = {
        image = "ghcr.io/soju06/codex-lb@sha256:7ec3560e29cf5ad8350c1ab73eba5ecbe7a1ab77382073bb76c782b94307c105";
        dependsOn = lib.optionals tailscaleSidecar.enable [ tailscaleSidecar.containerName ];
        podman = {
          user = username;
        };
        ports = lib.optionals (!tailscaleSidecar.enable) [
          "127.0.0.1:2455:2455"
          "127.0.0.1:1455:1455"
        ];
        environmentFiles = [
          config.sops.secrets."codex-lb-env".path
        ];
        volumes = [
          "/var/lib/codex-lb:/var/lib/codex-lb"
        ];
        extraOptions = codexLbExtraOptions;
      };
      "${tailscaleSocksProxy.containerName}" = lib.mkIf tailscaleSocksProxy.enable {
        image = tailscaleSocksProxy.image;
        imageStream = tailscaleSocksProxyImage;
        pull = "never";
        dependsOn = [ tailscaleSidecar.containerName ];
        podman = {
          user = username;
        };
        cmd = [
          "-q"
          "-i"
          "0.0.0.0"
          "-p"
          (toString tailscaleSocksProxy.listenPort)
        ];
        extraOptions = [ "--network=container:${tailscaleSidecar.containerName}" ];
      };
      "${tailscaleSidecar.containerName}" = lib.mkIf tailscaleSidecar.enable {
        image = "docker.io/tailscale/tailscale:stable";
        podman = {
          user = username;
        };
        # Provide TS_AUTHKEY from dedicated sops env file. / 専用の sops 環境変数ファイルから TS_AUTHKEY を読み込む。
        environmentFiles = [
          config.sops.secrets."tailscale-env".path
        ];
        environment = {
          TS_AUTH_ONCE = "true";
          TS_STATE_DIR = "/var/lib/tailscale";
          TS_SOCKET = "/tmp/tailscaled.sock";
          TS_USERSPACE = "false";
          TS_DEBUG_FIREWALL_MODE = "nftables";
          TS_EXTRA_ARGS = tailscaleSidecarExtraArgs;
        };
        ports = tailscaleSidecarPublishedPorts;
        volumes = [
          "${tailscaleSidecar.stateDir}:/var/lib/tailscale"
          "/dev/net/tun:/dev/net/tun"
        ];
        extraOptions = [
          "--cap-add=NET_ADMIN"
          "--cap-add=NET_RAW"
          "--device=/dev/net/tun"
        ] ++ tailscaleSidecarDnsExtraOptions;
      };
    } // lib.optionalAttrs tailscaleSidecar.enable tailscaleForwardSlotContainers;
  };

  # Ensure containers start after secrets are decrypted. / シークレット復号後にコンテナを起動。
  systemd.services."podman-openclaw" = {
    after = [ "sops-nix.service" ] ++ lib.optionals tailscaleSidecar.enable [ "podman-${tailscaleSidecar.containerName}.service" ];
    wants = [ "sops-nix.service" ] ++ lib.optionals tailscaleSidecar.enable [ "podman-${tailscaleSidecar.containerName}.service" ];
    startLimitIntervalSec = 0;
    restartTriggers = [
      config.sops.secrets."openclaw-env".sopsFile
    ];
    serviceConfig = {
      Restart = lib.mkForce "always";
      RestartSec = 5;
    };
  };
  systemd.services."podman-codex-lb" = {
    after = [ "sops-nix.service" ] ++ lib.optionals tailscaleSidecar.enable [ "podman-${tailscaleSidecar.containerName}.service" ];
    wants = [ "sops-nix.service" ] ++ lib.optionals tailscaleSidecar.enable [ "podman-${tailscaleSidecar.containerName}.service" ];
    startLimitIntervalSec = 0;
    restartTriggers = [
      config.sops.secrets."codex-lb-env".sopsFile
    ];
    serviceConfig = {
      Restart = lib.mkForce "always";
      RestartSec = 5;
    };
  };
  systemd.services."podman-${tailscaleSidecar.containerName}" = lib.mkIf tailscaleSidecar.enable {
    after = [ "sops-nix.service" ];
    wants = [ "sops-nix.service" ];
    startLimitIntervalSec = 0;
    restartTriggers = [
      config.sops.secrets."tailscale-env".sopsFile
    ];
    serviceConfig = {
      Restart = lib.mkForce "always";
      RestartSec = 5;
    };
  };
  # Set exit node after the sidecar is connected. / サイドカー接続後に exit node を設定。
  systemd.services."tailscale-set-exit-node" = lib.mkIf (tailscaleSidecar.enable && tailscaleSidecar.exitNode != null) {
    description = "Set Tailscale exit node for sidecar";
    after = [ "podman-${tailscaleSidecar.containerName}.service" ];
    requires = [ "podman-${tailscaleSidecar.containerName}.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      ExecStart = pkgs.writeShellScript "tailscale-set-exit-node" tailscaleSidecarPostStart;
    };
  };

  # Host-specific system packages. / ホスト専用の追加システムパッケージ。
  environment.systemPackages = with pkgs; [
    gamescope
    telegram-desktop
    limux
  ];
}
