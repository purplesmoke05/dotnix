{ config, lib, pkgs, ... }:

let
  cfg = config.hq.protonVpn;

  protonVpn = {
    interfaceName = "proton0";
    stateDir = "/var/lib/proton-vpn";
    runtimeDir = "/run/proton-vpn";
    sourceConfigFile = "/var/lib/proton-vpn/proton0.conf";
    runtimeConfigFile = "/run/proton-vpn/proton0.conf";
    dnsServers = [
      "tcp://10.2.0.1"
      "tcp://[2a07:b944::2:1]"
    ];
    dns4 = "10.2.0.1";
    dns6 = "2a07:b944::2:1";
    tailscaleInterface = "tailscale0";
    tailnet4 = "100.64.0.0/10";
    tailnet6 = "fd7a:115c:a1e0::/48";
    hotspotInterface = "wlan-hotspot0";
    hotspot4Address = "10.43.0.1";
    hotspot4 = "10.43.0.0/24";
    hotspotAllowedHostTcpPorts = [
      22
      53
    ];
    hotspotAllowedHostUdpPorts = [
      53
      67
      68
    ];
    allowTailscaleDirect = false;
    tailscalePort = 41641;
  };

  loadEndpointSet = pkgs.writeShellScript "proton-vpn-load-endpoint-set" ''
    set -euo pipefail

    conf=${lib.escapeShellArg protonVpn.runtimeConfigFile}

    if [ ! -f "$conf" ]; then
      echo "missing Proton WireGuard config: $conf" >&2
      exit 1
    fi

    endpoint="$(${pkgs.gawk}/bin/awk -F= '
      /^[[:space:]]*Endpoint[[:space:]]*=/ {
        value=$2
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
        exit
      }
    ' "$conf")"

    if [ -z "$endpoint" ]; then
      echo "missing Endpoint in Proton WireGuard config: $conf" >&2
      exit 1
    fi

    if [[ "$endpoint" =~ ^\[([0-9A-Fa-f:.]+)\]:([0-9]+)$ ]]; then
      host="''${BASH_REMATCH[1]}"
      port="''${BASH_REMATCH[2]}"
      family=ip6
    elif [[ "$endpoint" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):([0-9]+)$ ]]; then
      host="''${BASH_REMATCH[1]}"
      port="''${BASH_REMATCH[2]}"
      family=ip
    else
      echo "Proton Endpoint must be an IP literal, not a hostname: $endpoint" >&2
      exit 1
    fi

    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
      echo "invalid Proton Endpoint port: $endpoint" >&2
      exit 1
    fi

    ${pkgs.nftables}/bin/nft flush set inet proton-killswitch proton_vpn4_endpoints
    ${pkgs.nftables}/bin/nft flush set inet proton-killswitch proton_vpn6_endpoints

    case "$family" in
      ip)
        ${pkgs.nftables}/bin/nft add element inet proton-killswitch proton_vpn4_endpoints "{ $host . $port }"
        ;;
      ip6)
        ${pkgs.nftables}/bin/nft add element inet proton-killswitch proton_vpn6_endpoints "{ $host . $port }"
        ;;
    esac
  '';

  loadEndpointSetIfPresent = pkgs.writeShellScript "proton-vpn-load-endpoint-set-if-present" ''
    set -euo pipefail

    conf=${lib.escapeShellArg protonVpn.runtimeConfigFile}

    if [ ! -f "$conf" ]; then
      exit 0
    fi

    if ! ${pkgs.nftables}/bin/nft list table inet proton-killswitch >/dev/null 2>&1; then
      exit 0
    fi

    if ! ${loadEndpointSet}; then
      echo "warning: failed to refresh Proton VPN endpoint nftables set" >&2
    fi
  '';

  routeTailnetInProtonTable = pkgs.writeShellScript "proton-vpn-route-tailnet" ''
    set -euo pipefail

    iface=${lib.escapeShellArg protonVpn.tailscaleInterface}
    proton_iface=${lib.escapeShellArg protonVpn.interfaceName}
    tailnet4=${lib.escapeShellArg protonVpn.tailnet4}
    tailnet6=${lib.escapeShellArg protonVpn.tailnet6}

    for _ in $(${pkgs.coreutils}/bin/seq 1 20); do
      if ${pkgs.iproute2}/bin/ip link show "$iface" >/dev/null 2>&1; then
        break
      fi
      ${pkgs.coreutils}/bin/sleep 0.5
    done

    ${pkgs.iproute2}/bin/ip link show "$iface" >/dev/null

    if ! fwmark="$(${pkgs.wireguard-tools}/bin/wg show "$proton_iface" fwmark)"; then
      echo "missing WireGuard fwmark for $proton_iface" >&2
      exit 1
    fi

    if [ -z "$fwmark" ] || [ "$fwmark" = off ]; then
      echo "WireGuard fwmark is not set for $proton_iface" >&2
      exit 1
    fi

    printf -v table '%d' "$fwmark"

    if ! ${pkgs.iproute2}/bin/ip -4 route show table "$table" default dev "$proton_iface" \
      | ${pkgs.gnugrep}/bin/grep -q .; then
      echo "missing IPv4 Proton default route in table $table for $proton_iface" >&2
      exit 1
    fi

    if ! ${pkgs.iproute2}/bin/ip -6 route show table "$table" default dev "$proton_iface" \
      | ${pkgs.gnugrep}/bin/grep -q .; then
      echo "missing IPv6 Proton default route in table $table for $proton_iface" >&2
      exit 1
    fi

    ${pkgs.iproute2}/bin/ip -4 route replace "$tailnet4" dev "$iface" table "$table"
    ${pkgs.iproute2}/bin/ip -6 route replace "$tailnet6" dev "$iface" table "$table"
  '';

  triggerTailnetRoute = pkgs.writeShellScript "proton-vpn-trigger-tailnet-route" ''
    set -euo pipefail

    ${pkgs.systemd}/bin/systemctl reset-failed proton-vpn-tailnet-route.service >/dev/null 2>&1 || true
    ${pkgs.systemd}/bin/systemctl restart --no-block proton-vpn-tailnet-route.service >/dev/null 2>&1 || true
  '';

  triggerTailnetRouteIfProtonActive = pkgs.writeShellScript "proton-vpn-trigger-tailnet-route-if-proton-active" ''
    set -euo pipefail

    if ! ${pkgs.systemd}/bin/systemctl is-active --quiet wg-quick-${protonVpn.interfaceName}.service; then
      exit 0
    fi

    ${triggerTailnetRoute}
  '';

  triggerAdGuardHome = pkgs.writeShellScript "proton-vpn-trigger-adguardhome" ''
    set -euo pipefail

    ${pkgs.systemd}/bin/systemctl start --no-block adguardhome.service >/dev/null 2>&1 || true
  '';
in
{
  options.hq.protonVpn.enable = lib.mkEnableOption "Proton VPN routing for hq";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.networking.nat.enable;
        message = "Proton VPN routing expects networking.nat.enable for wlan-hotspot0.";
      }
      {
        assertion = builtins.elem protonVpn.hotspotInterface config.networking.nat.internalInterfaces;
        message = "Proton VPN routing expects wlan-hotspot0 in networking.nat.internalInterfaces.";
      }
      {
        assertion =
          let
            bindHosts = config.services.adguardhome.settings.dns.bind_hosts or [ ];
          in
          builtins.elem "0.0.0.0" bindHosts || builtins.elem protonVpn.hotspot4Address bindHosts;
        message = "Proton VPN hotspot DNS redirect expects AdGuard Home to listen on wlan-hotspot0.";
      }
    ];

    networking.nftables = {
      enable = true;
      tables."proton-hotspot-dns" = {
        family = "ip";
        content = ''
          chain prerouting {
            type nat hook prerouting priority -110; policy accept;

            iifname "${protonVpn.hotspotInterface}" udp dport 53 redirect to :53 comment "Hotspot DNS to AdGuard Home"
            iifname "${protonVpn.hotspotInterface}" tcp dport 53 redirect to :53 comment "Hotspot DNS to AdGuard Home"
          }
        '';
      };
      tables."proton-killswitch" = {
        family = "inet";
        content = ''
          set proton_vpn4_endpoints {
            type ipv4_addr . inet_service
          }

          set proton_vpn6_endpoints {
            type ipv6_addr . inet_service
          }

          chain output {
            type filter hook output priority 20; policy accept;

            oifname "lo" accept
            meta l4proto udp ip daddr . udp dport @proton_vpn4_endpoints accept comment "Proton WireGuard endpoint"
            meta l4proto udp ip6 daddr . udp dport @proton_vpn6_endpoints accept comment "Proton WireGuard endpoint"
            oifname "${protonVpn.interfaceName}" ip daddr ${protonVpn.dns4} udp dport 53 accept comment "Proton DNS"
            oifname "${protonVpn.interfaceName}" ip daddr ${protonVpn.dns4} tcp dport 53 accept comment "Proton DNS"
            oifname "${protonVpn.interfaceName}" ip6 daddr ${protonVpn.dns6} udp dport 53 accept comment "Proton DNS"
            oifname "${protonVpn.interfaceName}" ip6 daddr ${protonVpn.dns6} tcp dport 53 accept comment "Proton DNS"
            udp dport { 53, 853 } counter reject with icmpx admin-prohibited
            tcp dport { 53, 853 } counter reject with icmpx admin-prohibited
            oifname "${protonVpn.hotspotInterface}" ip daddr ${protonVpn.hotspot4} accept
            oifname "${protonVpn.tailscaleInterface}" ip daddr ${protonVpn.tailnet4} accept
            oifname "${protonVpn.tailscaleInterface}" ip6 daddr ${protonVpn.tailnet6} accept
            oifname "${protonVpn.tailscaleInterface}" counter reject with icmpx admin-prohibited
            ip daddr { 0.0.0.0/8, 10.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 255.255.255.255/32 } udp sport 68 udp dport 67 accept comment "DHCPv4 client"
            oifname "${protonVpn.hotspotInterface}" udp sport 67 udp dport 68 accept comment "DHCPv4 hotspot"
            ip6 daddr { fe80::/10, ff02::1:2 } udp sport 546 udp dport 547 accept comment "DHCPv6 client"
            oifname "${protonVpn.hotspotInterface}" udp sport 547 udp dport 546 accept comment "DHCPv6 hotspot"
            ip6 daddr { fe80::/10, ff02::/16 } icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert } accept comment "IPv6 neighbor discovery"
            ${lib.optionalString protonVpn.allowTailscaleDirect ''
            udp dport ${toString protonVpn.tailscalePort} accept comment "Tailscale direct path"
            ''}
            oifname "${protonVpn.interfaceName}" ip daddr ${protonVpn.tailnet4} counter reject with icmpx admin-prohibited
            oifname "${protonVpn.interfaceName}" ip6 daddr ${protonVpn.tailnet6} counter reject with icmpx admin-prohibited
            oifname "${protonVpn.interfaceName}" accept
            counter reject with icmpx admin-prohibited
          }

          chain input {
            type filter hook input priority 20; policy accept;

            iifname "${protonVpn.hotspotInterface}" ip saddr { 0.0.0.0/32, ${protonVpn.hotspot4} } udp sport 68 udp dport 67 accept
            iifname "${protonVpn.hotspotInterface}" ip saddr ${protonVpn.hotspot4} tcp dport { ${lib.concatMapStringsSep ", " toString protonVpn.hotspotAllowedHostTcpPorts} } accept
            iifname "${protonVpn.hotspotInterface}" ip saddr ${protonVpn.hotspot4} udp dport { ${lib.concatMapStringsSep ", " toString protonVpn.hotspotAllowedHostUdpPorts} } accept
            iifname "${protonVpn.hotspotInterface}" ip saddr ${protonVpn.hotspot4} icmp type echo-request accept
            iifname "${protonVpn.hotspotInterface}" counter reject with icmpx admin-prohibited
          }

          chain forward {
            type filter hook forward priority 20; policy accept;

            iifname "${protonVpn.interfaceName}" oifname "${protonVpn.hotspotInterface}" ct state established,related accept
            iifname "${protonVpn.hotspotInterface}" oifname "${protonVpn.interfaceName}" ip daddr ${protonVpn.tailnet4} counter reject with icmpx admin-prohibited
            iifname "${protonVpn.hotspotInterface}" oifname "${protonVpn.interfaceName}" ip6 daddr ${protonVpn.tailnet6} counter reject with icmpx admin-prohibited
            iifname "${protonVpn.hotspotInterface}" oifname "${protonVpn.interfaceName}" udp dport { 53, 853 } counter reject with icmpx admin-prohibited
            iifname "${protonVpn.hotspotInterface}" oifname "${protonVpn.interfaceName}" tcp dport { 53, 853 } counter reject with icmpx admin-prohibited
            iifname "${protonVpn.hotspotInterface}" oifname "${protonVpn.interfaceName}" accept
            iifname "${protonVpn.hotspotInterface}" counter reject with icmpx admin-prohibited
          }
        '';
      };
    };

    networking.firewall.interfaces.${protonVpn.hotspotInterface} = {
      allowedUDPPorts = protonVpn.hotspotAllowedHostUdpPorts;
      allowedTCPPorts = protonVpn.hotspotAllowedHostTcpPorts;
    };

    networking.firewall.filterForward = true;

    networking.nat.externalInterface = lib.mkForce protonVpn.interfaceName;

    services.adguardhome.settings.dns = {
      upstream_dns = lib.mkForce protonVpn.dnsServers;
      bootstrap_dns = lib.mkForce [ ];
    };

    networking.wg-quick.interfaces.${protonVpn.interfaceName} = {
      autostart = true;
      configFile = protonVpn.runtimeConfigFile;
    };

    system.activationScripts.validateProtonVpnConfig = {
      deps = [ "users" "groups" ];
      text = ''
        state_dir=${lib.escapeShellArg protonVpn.stateDir}
        conf=${lib.escapeShellArg protonVpn.sourceConfigFile}

        install -d -m 0700 -o root -g root "$state_dir"

        if [ ! -f "$conf" ]; then
          echo "missing Proton WireGuard config: $conf" >&2
          echo "create it from Proton's WireGuard config and use an IP-literal Endpoint" >&2
          exit 1
        fi

        chown root:root "$conf"
        chmod 0600 "$conf"

        if ! ${pkgs.gnugrep}/bin/grep -Eq '^[[:space:]]*Endpoint[[:space:]]*=[[:space:]]*((([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]+)|(\[[0-9A-Fa-f:.]+\]:[0-9]+))[[:space:]]*$' "$conf"; then
          echo "Endpoint in $conf must be an IP literal so the kill switch does not need pre-VPN DNS" >&2
          exit 1
        fi

        if ! ${pkgs.gnugrep}/bin/grep -Eq '^[[:space:]]*AllowedIPs[[:space:]]*=.*(^|[,[:space:]])0\.0\.0\.0/0([,[:space:]]|$)' "$conf"; then
          echo "AllowedIPs in $conf must include 0.0.0.0/0 for Proton default routing" >&2
          exit 1
        fi

        if ! ${pkgs.gnugrep}/bin/grep -Eq '^[[:space:]]*AllowedIPs[[:space:]]*=.*(^|[,[:space:]])::/0([,[:space:]]|$)' "$conf"; then
          echo "AllowedIPs in $conf must include ::/0 for Proton IPv6 default routing" >&2
          exit 1
        fi
      '';
    };

    systemd.services.nftables.serviceConfig = {
      ExecReload = lib.mkAfter [ "${loadEndpointSetIfPresent}" ];
      ExecStartPost = lib.mkAfter [ "${loadEndpointSetIfPresent}" ];
    };

    systemd.services.proton-vpn-prepare-config = {
      description = "Prepare Proton VPN WireGuard config";
      before = [
        "proton-vpn-load-endpoint-set.service"
        "wg-quick-${protonVpn.interfaceName}.service"
      ];
      requiredBy = [
        "proton-vpn-load-endpoint-set.service"
        "wg-quick-${protonVpn.interfaceName}.service"
      ];
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        source_conf=${lib.escapeShellArg protonVpn.sourceConfigFile}
        runtime_dir=${lib.escapeShellArg protonVpn.runtimeDir}
        runtime_conf=${lib.escapeShellArg protonVpn.runtimeConfigFile}

        install -d -m 0700 -o root -g root "$runtime_dir"
        tmp="$runtime_conf.tmp"

        ${pkgs.gawk}/bin/awk '
          /^[[:space:]]*[Dd][Nn][Ss][[:space:]]*=/ { next }
          { print }
        ' "$source_conf" > "$tmp"

        chown root:root "$tmp"
        chmod 0600 "$tmp"
        mv "$tmp" "$runtime_conf"
      '';
    };

    systemd.services.proton-vpn-load-endpoint-set = {
      description = "Load Proton VPN endpoint into nftables";
      after = [
        "nftables.service"
        "proton-vpn-prepare-config.service"
      ];
      before = [ "wg-quick-${protonVpn.interfaceName}.service" ];
      requires = [
        "nftables.service"
        "proton-vpn-prepare-config.service"
      ];
      requiredBy = [ "wg-quick-${protonVpn.interfaceName}.service" ];
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        ${loadEndpointSet}
      '';
    };

    systemd.services."wg-quick-${protonVpn.interfaceName}" = {
      after = [
        "proton-vpn-prepare-config.service"
        "proton-vpn-load-endpoint-set.service"
      ];
      requires = [
        "proton-vpn-prepare-config.service"
        "proton-vpn-load-endpoint-set.service"
      ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;
      };
      postStart = ''
        ${triggerTailnetRoute}
        ${triggerAdGuardHome}
      '';
    };

    systemd.services.proton-vpn-tailnet-route = {
      description = "Route tailnet traffic inside Proton VPN policy table";
      after = [
        "wg-quick-${protonVpn.interfaceName}.service"
        "tailscaled.service"
      ];
      wants = [ "tailscaled.service" ];
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = 5;
      };
      startLimitIntervalSec = 120;
      startLimitBurst = 24;
      script = ''
        ${routeTailnetInProtonTable}
      '';
    };

    systemd.services.tailscaled.postStart = lib.mkAfter ''
      ${triggerTailnetRouteIfProtonActive}
    '';

    systemd.services.adguardhome = {
      after = [ "wg-quick-${protonVpn.interfaceName}.service" ];
      wants = [ "wg-quick-${protonVpn.interfaceName}.service" ];
      bindsTo = [ "wg-quick-${protonVpn.interfaceName}.service" ];
      partOf = [ "wg-quick-${protonVpn.interfaceName}.service" ];
    };

    systemd.tmpfiles.rules = [
      "d ${protonVpn.stateDir} 0700 root root -"
      "d ${protonVpn.runtimeDir} 0700 root root -"
    ];

    environment.systemPackages = with pkgs; [
      nftables
      wireguard-tools
    ];
  };
}
