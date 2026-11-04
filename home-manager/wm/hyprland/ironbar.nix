{ config, lib, pkgs, hostname, ... }:
let
  codexIcon = pkgs.writeText "ironbar-codex-icon.svg" ''
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      fill="none"
      viewBox="0 0 24 24"
    >
      <path
        d="M13.795 23.856q-1.188 0-2.256-.448a6.1 6.1 0 0 1-1.9-1.247 5.8 5.8 0 0 1-1.875.306 5.8 5.8 0 0 1-2.944-.777 6.1 6.1 0 0 1-2.184-2.12q-.807-1.34-.808-2.99 0-.682.19-1.482a6.3 6.3 0 0 1-1.472-2.002 5.76 5.76 0 0 1 .024-4.85q.546-1.177 1.52-2.024a5.5 5.5 0 0 1 2.303-1.2A5.55 5.55 0 0 1 5.485 2.62 6.06 6.06 0 0 1 7.575.925 5.85 5.85 0 0 1 10.21.313q1.187 0 2.255.447a6.1 6.1 0 0 1 1.9 1.248 5.8 5.8 0 0 1 1.875-.306q1.59 0 2.944.776a5.9 5.9 0 0 1 2.16 2.12q.832 1.34.832 2.99 0 .682-.19 1.483a6.2 6.2 0 0 1 1.472 2.024q.522 1.13.522 2.378 0 1.272-.546 2.449a6.1 6.1 0 0 1-1.543 2.048 5.45 5.45 0 0 1-2.28 1.177 5.4 5.4 0 0 1-1.115 2.402 5.8 5.8 0 0 1-2.066 1.695 5.85 5.85 0 0 1-2.635.612M7.93 20.913q1.188 0 2.066-.495l4.463-2.542a.52.52 0 0 0 .238-.448v-2.024L8.95 18.676a.97.97 0 0 1-1.044 0L3.419 16.11a.7.7 0 0 1-.024.165v.282q0 1.201.57 2.213.594.99 1.639 1.554 1.044.59 2.326.589m.238-3.838q.143.07.26.07a.46.46 0 0 0 .238-.07l1.781-1.012-5.722-3.296q-.522-.306-.522-.918v-5.11a4.27 4.27 0 0 0-1.9 1.602 4.13 4.13 0 0 0-.712 2.354q0 1.155.594 2.213.593 1.06 1.543 1.601zm5.627 5.227q1.258 0 2.279-.565a4.25 4.25 0 0 0 1.614-1.554q.594-.99.594-2.213v-5.085q0-.283-.237-.424l-1.805-1.036v6.568q0 .613-.522.919l-4.487 2.566q1.163.825 2.564.824m.902-8.617v-3.202l-2.683-1.507-2.707 1.507v3.202l2.707 1.507zm-6.933-7.51q0-.612.522-.918l4.488-2.567a4.34 4.34 0 0 0-2.564-.824q-1.26 0-2.28.565a4.25 4.25 0 0 0-1.614 1.554q-.57.99-.57 2.213v5.062q0 .283.237.447l1.781 1.036zm12.061 11.253a4.13 4.13 0 0 0 1.876-1.6 4.2 4.2 0 0 0 .712-2.355q0-1.154-.593-2.213-.594-1.06-1.544-1.6l-4.44-2.543q-.142-.095-.26-.071a.46.46 0 0 0-.238.07l-1.78.99 5.745 3.319q.26.141.38.377a.9.9 0 0 1 .142.518zm-4.772-11.96q.522-.33 1.045 0l4.51 2.614v-.424q0-1.13-.57-2.142a4.1 4.1 0 0 0-1.59-1.648q-1.02-.613-2.374-.613-1.187 0-2.066.495L9.545 6.292a.52.52 0 0 0-.238.448v2.025z"
        fill="#cad3f5"
      />
    </svg>
  '';
  claudeIcon = pkgs.fetchurl {
    url = "https://cdn.prod.website-files.com/6889473510b50328dbb70ae6/689f4a9aff1f63fde75cf733_favicon.png";
    hash = "sha256-zn6Mr+J2xNaCA4dlLXdDd3L7Lvp1Eb/5Kk52ZM0r7lE=";
  };
  hasBattery = builtins.elem hostname [ "laptop" ];

  ironbarBin = lib.getExe pkgs.ironbar;
  systemctlBin = "${pkgs.systemd}/bin/systemctl";
  hyprctlBin = "/run/current-system/sw/bin/hyprctl";
  ironbarStartScript = lib.getExe (pkgs.writeShellApplication {
    name = "ironbar-start";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      set -eu

      wait_for_hyprland() {
        local monitors_json runtime_dir wayland_display wayland_socket

        runtime_dir="''${XDG_RUNTIME_DIR-}"
        if [ -z "$runtime_dir" ]; then
          runtime_dir="/run/user/$UID"
        fi

        for _ in $(seq 1 30); do
          wayland_display="''${WAYLAND_DISPLAY-}"
          wayland_socket="$runtime_dir/$wayland_display"

          if [ -n "$wayland_display" ] && [ -S "$wayland_socket" ]; then
            if monitors_json="$(${hyprctlBin} monitors -j 2>/dev/null)" \
              && printf '%s\n' "$monitors_json" \
                | jq -e 'type == "array" and length > 0 and all(.[]; (.name // "") != "")' >/dev/null
            then
              return 0
            fi
          fi

          sleep 1
        done

        printf 'Hyprland was not ready for ironbar: WAYLAND_DISPLAY=%s XDG_RUNTIME_DIR=%s\n' \
          "''${WAYLAND_DISPLAY-}" "$runtime_dir" >&2
        return 1
      }

      wait_for_hyprland
      exec ${ironbarBin}
    '';
  });
  ironbarHealthScript = lib.getExe (pkgs.writeShellApplication {
    name = "ironbar-health";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.ironbar
      pkgs.jq
    ];
    text = ''
      set -eu

      for _ in $(seq 1 20); do
        if timeout 3s ironbar ping >/dev/null 2>&1 \
          && ${hyprctlBin} layers -j 2>/dev/null \
            | jq -e '[to_entries[].value.levels | to_entries[].value[]? | select((.namespace // "") | startswith("ironbar"))] | length > 0' >/dev/null
        then
          exit 0
        fi

        sleep 1
      done

      printf 'Ironbar did not become visible and IPC-ready after startup\n' >&2
      exit 1
    '';
  });
  setDefaultSinkScript = lib.getExe (pkgs.writeShellApplication {
    name = "ironbar-set-default-sink";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.pulseaudio
      pkgs.systemd
    ];
    text = ''
      sink_name="''${1:-}"

      if [ "$#" -ne 1 ] || [ -z "$sink_name" ]; then
        printf 'usage: ironbar-set-default-sink SINK_NAME\n' >&2
        exit 2
      fi

      get_bluez_bool() {
        busctl get-property org.bluez "$device_path" org.bluez.Device1 "$1" | awk '{ print $2 }'
      }

      wait_bluez_resolved() {
        for _ in $(seq 1 20); do
          connected="$(get_bluez_bool Connected)"
          resolved="$(get_bluez_bool ServicesResolved)"

          if [ "$connected" = "true" ] && [ "$resolved" = "true" ]; then
            return 0
          fi

          sleep 0.25
        done

        return 1
      }

      wait_sink_visible() {
        for _ in $(seq 1 20); do
          if pactl list short sinks | awk '{ print $2 }' | grep -Fx "$sink_name" >/dev/null; then
            return 0
          fi

          sleep 0.25
        done

        return 1
      }

      reconnect_bluez() {
        for attempt in $(seq 1 3); do
          # Disconnect may fail after BlueZ has already dropped the transport.
          busctl call org.bluez "$device_path" org.bluez.Device1 Disconnect >/dev/null 2>&1 || true
          sleep 1

          if busctl call org.bluez "$device_path" org.bluez.Device1 Connect >/dev/null; then
            if wait_bluez_resolved; then
              return 0
            fi

            connected="$(get_bluez_bool Connected)"
            resolved="$(get_bluez_bool ServicesResolved)"
            printf 'Bluetooth reconnect attempt %s for %s did not resolve services: Connected=%s ServicesResolved=%s\n' \
              "$attempt" "$device_address" "$connected" "$resolved" >&2
          else
            printf 'Bluetooth reconnect attempt %s for %s failed\n' "$attempt" "$device_address" >&2
          fi
        done

        return 1
      }

      if [[ "$sink_name" == bluez_output.* ]]; then
        device_address="''${sink_name#bluez_output.}"
        device_address="''${device_address%%.*}"
        device_address="''${device_address//_/:}"
        device_object="dev_''${device_address//:/_}"
        device_path="$(
          busctl tree org.bluez \
            | awk -v device_object="$device_object" '{ path = $NF } path ~ ("/" device_object "$") { print path; exit }'
        )"

        if [ -z "$device_path" ]; then
          printf 'BlueZ device for sink %s was not found\n' "$sink_name" >&2
          exit 1
        fi

        connected="$(get_bluez_bool Connected)"
        resolved="$(get_bluez_bool ServicesResolved)"

        if [ "$connected" != "true" ] || [ "$resolved" != "true" ]; then
          printf 'Bluetooth device %s is Connected=%s ServicesResolved=%s; reconnecting before selecting %s\n' \
            "$device_address" "$connected" "$resolved" "$sink_name" >&2

          if ! reconnect_bluez; then
            connected="$(get_bluez_bool Connected)"
            resolved="$(get_bluez_bool ServicesResolved)"
            printf 'Bluetooth device %s did not recover: Connected=%s ServicesResolved=%s\n' \
              "$device_address" "$connected" "$resolved" >&2
            exit 1
          fi
        fi

        if ! wait_sink_visible; then
          printf 'PipeWire/Pulse sink %s is not visible after Bluetooth readiness check\n' "$sink_name" >&2
          exit 1
        fi
      fi

      exec pactl set-default-sink "$sink_name"
    '';
  });
  cpuUsageScript = lib.getExe (pkgs.writeShellApplication {
    name = "ironbar-cpu-usage";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
    ];
    text = ''
      read -r _ _user1 _nice1 _system1 _idle1 _iowait1 _irq1 _softirq1 _steal1 _guest1 _guestnice1 < /proc/stat
      total1=$((_user1 + _nice1 + _system1 + _idle1 + _iowait1 + _irq1 + _softirq1 + _steal1 + _guest1 + _guestnice1))
      idle_total1=$((_idle1 + _iowait1))

      sleep 0.2

      read -r _ _user2 _nice2 _system2 _idle2 _iowait2 _irq2 _softirq2 _steal2 _guest2 _guestnice2 < /proc/stat
      total2=$((_user2 + _nice2 + _system2 + _idle2 + _iowait2 + _irq2 + _softirq2 + _steal2 + _guest2 + _guestnice2))
      idle_total2=$((_idle2 + _iowait2))

      total_delta=$((total2 - total1))
      idle_delta=$((idle_total2 - idle_total1))

      if [ "$total_delta" -le 0 ]; then
        cpu_percent=0
      else
        cpu_percent=$((((100 * (total_delta - idle_delta)) + (total_delta / 2)) / total_delta))
      fi

      if [ "$cpu_percent" -ge 90 ]; then
        printf '<span foreground="#ed8796">%s%%</span>\n' "$cpu_percent"
      elif [ "$cpu_percent" -ge 80 ]; then
        printf '<span foreground="#f5a97f">%s%%</span>\n' "$cpu_percent"
      else
        printf '%s%%\n' "$cpu_percent"
      fi
    '';
  });
  memoryUsageScript = lib.getExe (pkgs.writeShellApplication {
    name = "ironbar-memory-usage";
    runtimeInputs = [
      pkgs.gawk
      pkgs.procps
    ];
    text = ''
      memory_percent="$(free | awk '/^Mem:/ { printf "%.0f\n", ($3 / $2) * 100 }')"

      case "$memory_percent" in
        ""|*[!0-9]*)
          printf '--\n'
          exit 0
          ;;
      esac

      if [ "$memory_percent" -ge 90 ]; then
        printf '<span foreground="#ed8796">%s%%</span>\n' "$memory_percent"
      elif [ "$memory_percent" -ge 80 ]; then
        printf '<span foreground="#f5a97f">%s%%</span>\n' "$memory_percent"
      else
        printf '%s%%\n' "$memory_percent"
      fi
    '';
  });
  diskUsagePreferredMount = "/";
  diskUsageScript = lib.getExe (pkgs.writeShellApplication {
    name = "ironbar-disk-usage";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      preferred_target="${diskUsagePreferredMount}"
      target_path="/"

      if [ "$preferred_target" = "/" ] || findmnt -rn -M "$preferred_target" >/dev/null 2>&1; then
        target_path="$preferred_target"
      fi

      usage="$(df --output=pcent "$target_path" | tail -n +2 | tr -dc '0-9')"

      case "$usage" in
        ""|*[!0-9]*)
          printf '--\n'
          exit 0
          ;;
      esac

      if [ "$usage" -ge 90 ]; then
        printf '<span foreground="#ed8796">%s%%</span>\n' "$usage"
      elif [ "$usage" -ge 80 ]; then
        printf '<span foreground="#f5a97f">%s%%</span>\n' "$usage"
      else
        printf '%s%%\n' "$usage"
      fi
    '';
  });
  vulnStatusStaleSeconds = 36 * 60 * 60;
  vulnStatusFindingLimit = 12;
  vulnStatusDisplayLimit = 6;
  # Days since the deployed nixpkgs revision before the NIX segment turns yellow
  # or red. Browser and Electron security releases reach nixpkgs within days.
  vulnStatusLagWarnDays = 14;
  vulnStatusLagAlertDays = 30;
  vulnStatusSbomKeep = 5;
  # Findings reviewed as not applicable. Each entry names an exact package
  # version, so its findings count again once the version changes and need a new
  # review.
  vulnStatusReviewed = pkgs.writeText "nix-vuln-status-reviewed.json" (builtins.toJSON [
    {
      # Commits in nixpkgs' 2.44-master.patch fix these, except CVE-2026-0861,
      # which GLIBC-SA-2026-0001 lists as fixed since 2.43.
      package = "glibc";
      version = "2.44-57";
      ids = [
        "CVE-2026-0861"
        "CVE-2026-18374"
        "CVE-2026-19499"
        "CVE-2026-19542"
        "CVE-2026-77117"
        "CVE-2026-80489"
        "CVE-2026-8674"
        "CVE-2026-86805"
        "CVE-2026-89092"
        "CVE-2026-95818"
        "CVE-2026-97399"
      ];
    }
    {
      # The CPE ranges have no upper bound. The Debian security tracker lists
      # the fixes in 4.19 to 6.7.
      package = "linux";
      version = "7.3.1";
      ids = [
        "CVE-2019-3016"
        "CVE-2019-3819"
        "CVE-2019-3887"
        "CVE-2020-27815"
        "CVE-2021-20194"
        "CVE-2021-3564"
        "CVE-2022-38096"
      ];
    }
    {
      # Only affects the AArch64 stack protector. These hosts are x86_64.
      package = "gcc";
      version = "16.2.0";
      ids = [ "CVE-2023-4039" ];
    }
    {
      package = "gcc-wrapper";
      version = "16.2.0";
      ids = [ "CVE-2023-4039" ];
    }
    {
      # Both advisories list 5.42.3-RC1 as the fix. The CPE ranges ignore that
      # branch.
      package = "perl";
      version = "5.42.3";
      ids = [
        "CVE-2026-13221"
        "CVE-2026-57432"
      ];
    }
    {
      # CVE-2024-3220 only affects Windows. CVE-2026-87910 needs a system without
      # link support.
      package = "python3";
      version = "3.14.8";
      ids = [
        "CVE-2024-3220"
        "CVE-2026-87910"
      ];
    }
    {
      # GnuTLS and wolfSSL builds only. Every libcurl in the closure links OpenSSL.
      package = "curl";
      version = "8.22.0";
      ids = [
        "CVE-2026-107928"
        "CVE-2026-87866"
      ];
    }
    {
      # 2.42.4 is only affected on the legacy mount(2) path without /proc.
      package = "util-linux";
      version = "2.42.4";
      ids = [ "CVE-2026-53613" ];
    }
    {
      # Needs the recursive-nix experimental feature, which is not enabled.
      package = "nix";
      version = "2.34.9";
      ids = [ "CVE-2026-64846" ];
    }
    {
      # These need the Unbound daemon. Only libunbound is present, linked by
      # libgnutls-dane, which nothing in the closure links.
      package = "unbound";
      version = "1.26.1";
      ids = [
        "CVE-2026-109125"
        "CVE-2026-35501"
        "CVE-2026-50106"
        "CVE-2026-96405"
        "CVE-2026-97206"
      ];
    }
  ]);
  vulnStatusStatusColor = ''
    def color:
      if . == "ok" then "#a6da95"
      elif . == "warn" or . == "missing" then "#eed49f"
      elif . == "alert" or . == "error" then "#ed8796"
      else "#a5adcb"
      end;
  '';
  nixVulnStatusSbom = pkgs.writeShellApplication {
    name = "nix-vuln-status-sbom";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.diffutils
      pkgs.findutils
      pkgs.jq
      pkgs.nix
      pkgs.sbomnix
    ];
    text = ''
      set -euo pipefail

      usage() {
        printf '%s\n' \
          "Usage: nix-vuln-status-sbom --flake PATH [--config NAME] [--public-nix PATH] [--expect STORE_PATH]" \
          "" \
          "Generates the SBOM that nix-vuln-status-refresh scans for the NixOS system" \
          "built from the flake at PATH. The SBOM is saved only when the evaluated" \
          "system equals --expect (default: /run/current-system)." >&2
      }

      flake=""
      config_name="hq"
      public_nix=""
      expect=""

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --flake|--config|--public-nix|--expect)
            if [ "$#" -lt 2 ]; then
              usage
              exit 2
            fi
            case "$1" in
              --flake) flake="$2" ;;
              --config) config_name="$2" ;;
              --public-nix) public_nix="$2" ;;
              --expect) expect="$2" ;;
            esac
            shift
            ;;
          -h|--help)
            usage
            exit 0
            ;;
          *)
            usage
            exit 2
            ;;
        esac
        shift
      done

      if [ -z "$flake" ]; then
        usage
        exit 2
      fi

      flake="$(realpath "$flake")"
      if [ -n "$public_nix" ]; then
        public_nix="$(realpath "$public_nix")"
      fi
      if [ -z "$expect" ]; then
        expect="$(readlink -f /run/current-system)"
      fi

      cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/nix-vuln-status"
      sbom_dir="$cache_dir/sbom"
      wrapper_dir="$cache_dir/sbom-flake"
      mkdir -p "$sbom_dir" "$wrapper_dir"
      work_dir="$(mktemp -d "$cache_dir/sbom.XXXXXX")"
      trap 'rm -rf "$work_dir"' EXIT

      started_epoch="$(date -u +%s)"

      # sbomnix cannot pass --override-input, so a wrapper flake re-exports the
      # target with public-nix overridden the same way `make switch` does.
      {
        printf '{\n'
        printf '  inputs.target.url = "path:%s";\n' "$flake"
        if [ -n "$public_nix" ]; then
          printf '  inputs.target.inputs.public-nix.url = "path:%s";\n' "$public_nix"
        fi
        printf '  outputs = { target, ... }: { inherit (target) nixosConfigurations; };\n'
        printf '}\n'
      } > "$work_dir/flake.nix"
      if ! cmp -s "$work_dir/flake.nix" "$wrapper_dir/flake.nix"; then
        mv "$work_dir/flake.nix" "$wrapper_dir/flake.nix"
        rm -f "$wrapper_dir/flake.lock"
      fi

      # A new lock copies the public-nix narHash from the target's own lock,
      # which is stale whenever public-nix has local changes, so both inputs
      # are fetched again explicitly.
      update_inputs=(target)
      if [ -n "$public_nix" ]; then
        update_inputs+=(target/public-nix)
      fi
      nix flake update --flake "path:$wrapper_dir" "''${update_inputs[@]}"

      # sbomnix builds its target, so a flake that has moved on since the build
      # is rejected before anything is built.
      toplevel_ref="path:$wrapper_dir#nixosConfigurations.$config_name.config.system.build.toplevel"
      evaluated="$(nix eval --raw "$toplevel_ref.outPath")"
      if [ "$evaluated" != "$expect" ]; then
        printf 'nix-vuln-status-sbom: the flake evaluates to %s, not %s; it no longer matches that system, so no SBOM was generated\n' \
          "$evaluated" "$expect" >&2
        exit 1
      fi

      (
        cd "$work_dir"
        sbomnix --verbose 0 --exclude-cpe-matching --cdx "$work_dir/sbom.cdx.json" "$toplevel_ref"
      )

      output_path="$(jq -r '[.metadata.component.properties[]? | select(.name == "nix:output_path") | .value][0] // ""' "$work_dir/sbom.cdx.json")"
      if [ "$output_path" != "$expect" ]; then
        printf 'nix-vuln-status-sbom: evaluated %s but expected %s; the flake no longer matches that system, so the SBOM was not saved\n' \
          "''${output_path:-nothing}" "$expect" >&2
        exit 1
      fi

      name="$(basename "$expect")"
      components="$(jq '(.components // []) | length' "$work_dir/sbom.cdx.json")"
      with_cpe="$(jq '[.components[]? | select((.cpe // "") != "")] | length' "$work_dir/sbom.cdx.json")"
      finished_epoch="$(date -u +%s)"
      jq -n \
        --arg generatedAt "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        --argjson generatedAtEpoch "$finished_epoch" \
        --argjson durationSeconds "$((finished_epoch - started_epoch))" \
        --arg toplevel "$expect" \
        --arg flake "$flake" \
        --arg config "$config_name" \
        --arg publicNix "$public_nix" \
        --arg sbomnix "${pkgs.sbomnix.version}" \
        --argjson components "$components" \
        --argjson componentsWithCpe "$with_cpe" \
        '{
          generatedAt: $generatedAt,
          generatedAtEpoch: $generatedAtEpoch,
          durationSeconds: $durationSeconds,
          toplevel: $toplevel,
          flake: $flake,
          config: $config,
          publicNix: (if $publicNix == "" then null else $publicNix end),
          sbomnix: $sbomnix,
          components: $components,
          componentsWithCpe: $componentsWithCpe
        }' > "$work_dir/meta.json"
      mv "$work_dir/sbom.cdx.json" "$sbom_dir/$name.cdx.json"
      mv "$work_dir/meta.json" "$sbom_dir/$name.meta.json"

      # Keep SBOMs for the newest systems only; rollbacks rarely go further back.
      find "$sbom_dir" -maxdepth 1 -name '*.cdx.json' -printf '%T@ %p\n' \
        | sort -rn \
        | tail -n +${builtins.toString (vulnStatusSbomKeep + 1)} \
        | cut -d' ' -f2- \
        | while IFS= read -r old_sbom; do
            rm -f "$old_sbom" "''${old_sbom%.cdx.json}.meta.json"
          done

      printf 'nix-vuln-status-sbom: %s components, %s with an exact CPE -> %s\n' \
        "$components" "$with_cpe" "$sbom_dir/$name.cdx.json"
    '';
  };
  nixVulnStatusRefresh = pkgs.writeShellApplication {
    name = "nix-vuln-status-refresh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.findutils
      pkgs.gawk
      pkgs.gnused
      pkgs.go
      pkgs.govulncheck
      pkgs.grype
      pkgs.jq
      pkgs.nix
      pkgs.unzip
    ];
    text = ''
      set -euo pipefail

      cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/nix-vuln-status"
      status_file="$cache_dir/status.json"
      sbom_dir="$cache_dir/sbom"
      target_path="''${NIX_VULN_STATUS_TARGET:-/run/current-system}"

      mkdir -p "$cache_dir"
      work_dir="$(mktemp -d "$cache_dir/scan.XXXXXX")"
      started_epoch="$(date -u +%s)"
      status_written=0

      # A go.mod with a toolchain line in the working directory must not make
      # `go version` download another toolchain.
      export GOTOOLCHAIN=local
      cd "$work_dir"

      write_failure() {
        jq -n \
          --arg generatedAt "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
          --argjson generatedAtEpoch "$(date -u +%s)" \
          --arg message "$1" \
          '{
            schema: 2,
            generatedAt: $generatedAt,
            generatedAtEpoch: $generatedAtEpoch,
            status: "error",
            error: $message,
            checks: {}
          }' > "$cache_dir/status.json.tmp"
        mv "$cache_dir/status.json.tmp" "$status_file"
      }

      finish() {
        local exit_code=$?
        if [ "$status_written" -eq 0 ]; then
          write_failure "refresh stopped with exit $exit_code; see journalctl --user -u nix-vuln-status" || true
        fi
        rm -rf "$work_dir"
      }
      trap finish EXIT

      summarize_log() {
        if [ ! -s "$1" ]; then
          printf 'no output'
          return 0
        fi
        tr '\n' ' ' < "$1" | cut -c 1-200
      }

      # Saves the JSON at the URL, or `null` when it cannot be fetched, so that
      # jq --slurpfile always has something to read.
      fetch_json() {
        if curl -fsSL --max-time 60 --retry 2 -o "$2" "$1" 2>> "$work_dir/fetch.log" \
          && jq -e . "$2" > /dev/null 2>&1; then
          return 0
        fi
        printf 'null\n' > "$2"
        printf '%s\n' "$1" >> "$work_dir/fetch-failed.txt"
      }

      target_store_path="$(readlink -f "$target_path" 2> /dev/null || true)"
      if [ -z "$target_store_path" ] || [ ! -e "$target_store_path" ]; then
        write_failure "scan target does not exist: $target_path"
        status_written=1
        exit 1
      fi
      target_name="$(basename "$target_store_path")"
      nix-store --query --requisites "$target_store_path" > "$work_dir/closure.txt"
      : > "$work_dir/fetch-failed.txt"

      # CVE: grype against the SBOM that `make switch` generated for this
      # system. Only packages with an exact nixpkgs CPE can match, and matches
      # without a version range, fixed by a CVE-named patch, or listed in
      # vulnStatusReviewed are not counted.
      sbom_file="$sbom_dir/$target_name.cdx.json"
      sbom_meta="$sbom_dir/$target_name.meta.json"
      if [ ! -s "$sbom_meta" ]; then
        sbom_meta="$work_dir/sbom-meta.json"
        printf '{}\n' > "$sbom_meta"
      fi
      if [ ! -s "$sbom_file" ]; then
        jq -n '{status: "missing", message: "No SBOM for this system yet. make switch generates it after the build."}' \
          > "$work_dir/cve.json"
      elif ! grype -q "sbom:$sbom_file" -o json --file "$work_dir/grype.json" > "$work_dir/grype.log" 2>&1 \
        || ! jq -e . "$work_dir/grype.json" > /dev/null 2>&1; then
        jq -n --arg message "grype failed: $(summarize_log "$work_dir/grype.log")" '{status: "error", message: $message}' \
          > "$work_dir/cve.json"
      else
        jq -n \
          --slurpfile sbom "$sbom_file" \
          --slurpfile grype "$work_dir/grype.json" \
          --slurpfile meta "$sbom_meta" \
          --slurpfile reviewed ${vulnStatusReviewed} \
          --argjson limit ${builtins.toString vulnStatusFindingLimit} \
          '
            def sevrank:
              (.severity // "" | ascii_downcase) as $severity
              | if $severity == "critical" then 0
                elif $severity == "high" then 1
                elif $severity == "medium" then 2
                elif $severity == "low" then 3
                else 4
                end;
            # sbomnix writes timestamps such as 2026-11-03T19:36:26.396335+09:00,
            # which fromdateiso8601 cannot parse.
            def isoepoch:
              (capture("^(?<datetime>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(\\.[0-9]+)?(?<zone>Z|[+-][0-9]{2}:[0-9]{2})$") // null) as $parts
              | if $parts == null then null
                else ($parts.datetime + "Z" | fromdateiso8601)
                  - (if $parts.zone == "Z" then 0
                     else (($parts.zone[1:3] | tonumber) * 3600 + ($parts.zone[4:6] | tonumber) * 60)
                       * (if $parts.zone[0:1] == "-" then -1 else 1 end)
                     end)
                end;
            ($sbom[0].components // []) as $components
            | ($components
                | map(select(.purl != null) | {key: .purl, value: [(.pedigree.patches // [])[].resolves[]?.id | ascii_upcase]})
                | from_entries) as $patched
            | ($reviewed[0]
                | map(. as $entry | $entry.ids[] | {key: "\($entry.package) \($entry.version) \(.)", value: true})
                | from_entries) as $reviewedKeys
            | [ $grype[0].matches[]?
                | . as $match
                | ($match.artifact.purl // "") as $purl
                | ([$match.vulnerability.id // ""] + [($match.relatedVulnerabilities // [])[] | .id // empty] | map(ascii_upcase)) as $ids
                | {
                    id: ($match.vulnerability.id // "unknown"),
                    severity: ($match.vulnerability.severity // "Unknown"),
                    package: ($match.artifact.name // "unknown"),
                    version: ($match.artifact.version // "unknown"),
                    fixVersions: (($match.vulnerability.fix.versions // [])[:3]),
                    ranged: ([$match.matchDetails[]?.found.versionConstraint // "none"] | any(startswith("none")) | not),
                    patched: any($ids[]; . as $id | (($patched[$purl] // []) | index($id)) != null),
                    reviewed: any($ids[]; $reviewedKeys["\($match.artifact.name // "") \($match.artifact.version // "") \(.)"] // false)
                  }
              ] as $rows
            | ($rows | map(select(.ranged and (.patched | not) and (.reviewed | not)))) as $counted
            # One CVE can match several packages, such as ffmpeg and ffmpeg-headless.
            # Totals count it once. The package list still shows every match.
            | ($counted | unique_by(.id)) as $distinct
            | ([$distinct[] | select(sevrank <= 1)] | length) as $highOrCritical
            | {
                status: (
                  if ($counted | length) == 0 then "ok"
                  elif $highOrCritical > 0 then "alert"
                  else "warn"
                  end
                ),
                count: ($distinct | length),
                matches: ($counted | length),
                highOrCritical: $highOrCritical,
                bySeverity: ($distinct | group_by(.severity) | map({key: .[0].severity, value: length}) | from_entries),
                excluded: {
                  noVersionRange: ([$rows[] | select(.ranged | not)] | length),
                  patched: ([$rows[] | select(.ranged and .patched)] | length),
                  reviewed: ([$rows[] | select(.ranged and (.patched | not) and .reviewed)] | length)
                },
                coverage: {
                  components: ($components | length),
                  withCpe: ([$components[] | select((.cpe // "") != "")] | length)
                },
                sbom: {
                  generatedAt: ($meta[0].generatedAt // $sbom[0].metadata.timestamp // null),
                  generatedAtEpoch: ($meta[0].generatedAtEpoch // ($sbom[0].metadata.timestamp // "" | isoepoch) // null)
                },
                packages: (
                  $counted
                  | group_by([.package, .version])
                  | map({package: .[0].package, version: .[0].version, count: length, worst: (map(sevrank) | min)})
                  | sort_by(.worst, -.count)
                  | .[:$limit]
                ),
                findings: (
                  $counted
                  | unique_by([.id, .package, .version])
                  | sort_by(sevrank, .package, .id)
                  | .[:$limit]
                  | map(del(.ranged, .patched, .reviewed))
                )
              }
          ' > "$work_dir/cve.json"
      fi

      # GO: govulncheck on every Go binary in the closure. Only findings whose
      # vulnerable function is present in the binary are counted.
      while IFS= read -r store_path; do
        for sub_dir in bin libexec; do
          if [ -d "$store_path/$sub_dir" ]; then
            printf '%s\n' "$store_path/$sub_dir"
          fi
        done
      done < "$work_dir/closure.txt" > "$work_dir/bin-dirs.txt"
      : > "$work_dir/go-version.txt"
      if [ -s "$work_dir/bin-dirs.txt" ]; then
        xargs -a "$work_dir/bin-dirs.txt" go version > "$work_dir/go-version.txt" 2> /dev/null || true
      fi
      sed -nE 's/^(.*): (go[0-9][^ ]*)$/\1\t\2/p' "$work_dir/go-version.txt" \
        | while IFS=$'\t' read -r bin_path go_version; do
            printf '%s\t%s\n' "$(readlink -f "$bin_path")" "$go_version"
          done \
        | sort -u -t $'\t' -k1,1 > "$work_dir/go-binaries.tsv"

      go_db_dir="$work_dir/go-vulndb"
      if [ ! -s "$work_dir/go-binaries.tsv" ]; then
        jq -n '{status: "ok", binaries: 0, scanned: 0, failed: 0, affectedBinaries: 0, count: 0, stdlib: 0, modules: 0, goVersions: [], binariesTop: [], findings: []}' \
          > "$work_dir/go.json"
      elif ! curl -fsSL --max-time 120 --retry 2 -o "$work_dir/vulndb.zip" https://vuln.go.dev/vulndb.zip 2> "$work_dir/vulndb.log" \
        || ! unzip -q "$work_dir/vulndb.zip" -d "$go_db_dir" 2>> "$work_dir/vulndb.log"; then
        jq -n --arg message "Go vulnerability database download failed: $(summarize_log "$work_dir/vulndb.log")" '{status: "error", message: $message}' \
          > "$work_dir/go.json"
      else
        mkdir -p "$work_dir/go"
        index=0
        while IFS=$'\t' read -r bin_path go_version; do
          index=$((index + 1))
          if govulncheck -mode=binary -db "file://$go_db_dir" -format json "$bin_path" > "$work_dir/go/raw.json" 2> "$work_dir/go/raw.err"; then
            jq -s \
              --arg binary "$bin_path" \
              --arg go "$go_version" \
              '
                (map(select(.osv) | .osv | {key: .id, value: {summary: (.summary // ""), cves: [(.aliases // [])[] | select(startswith("CVE-"))]}}) | from_entries) as $osv
                | [ .[] | select(.finding) | .finding
                    | select((.trace[0].function // "") != "")
                    | {id: .osv, module: (.trace[0].module // "unknown"), fixed: (.fixed_version // null)}
                  ]
                | unique_by(.id)
                | {binary: $binary, go: $go, vulns: map(. + ($osv[.id] // {summary: "", cves: []}))}
              ' "$work_dir/go/raw.json" > "$work_dir/go/$index.json"
          else
            jq -n \
              --arg binary "$bin_path" \
              --arg go "$go_version" \
              --arg error "$(summarize_log "$work_dir/go/raw.err")" \
              '{binary: $binary, go: $go, error: $error, vulns: []}' > "$work_dir/go/$index.json"
          fi
        done < "$work_dir/go-binaries.tsv"
        rm -f "$work_dir/go/raw.json" "$work_dir/go/raw.err"
        jq -s \
          --argjson limit ${builtins.toString vulnStatusFindingLimit} \
          '
            def display:
              (capture("^/nix/store/[a-z0-9]{32}-(?<pkg>[^/]+)/(.*/)?(?<file>[^/]+)$") // null) as $parts
              | if $parts == null then .
                else ($parts.file | sub("^\\."; "") | sub("-wrapped$"; "")) + " (" + $parts.pkg + ")"
                end;
            . as $bins
            | [$bins[] | select(.error == null)] as $scanned
            | ([$scanned[] | .vulns[]] | unique_by(.id)) as $distinct
            | {
                status: (
                  if ($bins | length) > 0 and ($scanned | length) == 0 then "error"
                  elif ($distinct | length) > 0 then "warn"
                  else "ok"
                  end
                ),
                binaries: ($bins | length),
                scanned: ($scanned | length),
                failed: (($bins | length) - ($scanned | length)),
                affectedBinaries: ([$scanned[] | select((.vulns | length) > 0)] | length),
                count: ($distinct | length),
                stdlib: ([$distinct[] | select(.module == "stdlib")] | length),
                modules: ([$distinct[] | select(.module != "stdlib")] | length),
                goVersions: ($bins | group_by(.go) | map({go: .[0].go, binaries: length}) | sort_by(-.binaries)),
                binariesTop: (
                  $scanned
                  | map(select((.vulns | length) > 0) | {name: (.binary | display), count: (.vulns | length)})
                  | sort_by(-.count, .name)
                  | .[:$limit]
                ),
                findings: (
                  [$scanned[] | .vulns[]]
                  | group_by(.id)
                  | map(.[0] + {binaries: length})
                  | sort_by(-.binaries, .id)
                  | .[:$limit]
                )
              }
          ' "$work_dir"/go/[0-9]*.json > "$work_dir/go.json"
      fi

      # NIX: how far the deployed system is behind. Most fixes arrive through a
      # nixpkgs update, so the age of the nixpkgs revision is the main signal;
      # end-of-life kernels and Electron runtimes and outdated browsers are
      # checked against their upstream release data.
      nixos_version="$(cat "$target_store_path/nixos-version" 2> /dev/null || true)"
      system_kernel="$(find "$target_store_path/kernel-modules/lib/modules" -mindepth 1 -maxdepth 1 -printf '%f\n' 2> /dev/null | head -n 1 || true)"
      running_kernel="$(uname -r)"

      fetch_json https://www.kernel.org/releases.json "$work_dir/kernel-releases.json"
      fetch_json https://releases.electronjs.org/releases.json "$work_dir/electron-releases.json"
      fetch_json 'https://versionhistory.googleapis.com/v1/chrome/platforms/linux/channels/stable/versions?pageSize=1' "$work_dir/chrome-versions.json"
      fetch_json 'https://api.github.com/repos/brave/brave-browser/releases?per_page=40' "$work_dir/brave-releases.json"

      awk '/-electron-[0-9]+\.[0-9]+\.[0-9]+/ && !/-(unwrapped|fish-completions)$/' "$work_dir/closure.txt" \
        | while IFS= read -r electron_path; do
            electron_name="''${electron_path#/nix/store/*-}"
            nix-store --query --referrers "$electron_path" \
              | awk 'NR == FNR { closure[$0] = 1; next } ($0 in closure)' "$work_dir/closure.txt" - \
              | sed -E 's#^/nix/store/[a-z0-9]{32}-##' \
              | awk '!/^electron|fish-completions|-unwrapped/' \
              | jq -R . \
              | jq -s --arg name "$electron_name" \
                '{name: $name, version: ($name | capture("^electron-(?<version>[0-9]+\\.[0-9]+\\.[0-9]+)").version), apps: unique}'
          done \
        | jq -s . > "$work_dir/electrons.json"

      sed -E 's#^/nix/store/[a-z0-9]{32}-##' "$work_dir/closure.txt" \
        | awk '/^(brave|google-chrome|chromium)-[0-9][0-9.]*$/' \
        | sort -u \
        | jq -R 'capture("^(?<name>.+)-(?<version>[0-9][0-9.]*)$")' \
        | jq -s . > "$work_dir/browsers.json"

      jq -n \
        --arg nixosVersion "$nixos_version" \
        --arg runningKernel "$running_kernel" \
        --arg systemKernel "$system_kernel" \
        --argjson nowEpoch "$started_epoch" \
        --argjson warnDays ${builtins.toString vulnStatusLagWarnDays} \
        --argjson alertDays ${builtins.toString vulnStatusLagAlertDays} \
        --slurpfile kernelReleases "$work_dir/kernel-releases.json" \
        --slurpfile electronReleases "$work_dir/electron-releases.json" \
        --slurpfile chromeVersions "$work_dir/chrome-versions.json" \
        --slurpfile braveReleases "$work_dir/brave-releases.json" \
        --slurpfile electrons "$work_dir/electrons.json" \
        --slurpfile browsers "$work_dir/browsers.json" \
        --rawfile unreachable "$work_dir/fetch-failed.txt" \
        '
          def vkey: [scan("[0-9]+") | tonumber];
          ($nixosVersion | capture("\\.(?<date>[0-9]{8})\\.(?<rev>[0-9a-f]+)$") // null) as $nixpkgs
          | (if $nixpkgs == null then null
             else (($nowEpoch - ($nixpkgs.date | strptime("%Y%m%d") | mktime)) / 86400 | floor)
             end) as $ageDays
          | (($runningKernel | capture("^(?<series>[0-9]+\\.[0-9]+)") | .series) // null) as $series
          | (if $kernelReleases[0] == null then null
             else [$kernelReleases[0].releases[] | select(.moniker != "linux-next")]
             end) as $kernels
          | (if $kernels == null or $series == null then null
             else ([$kernels[] | select(.version | startswith($series + "."))] | first)
             end) as $seriesRelease
          | (if $kernels == null or $series == null then null
             elif $seriesRelease == null then true
             else $seriesRelease.iseol == true
             end) as $kernelEol
          | (if $kernels == null then null
             else ([$kernels[] | select(.moniker == "stable" and (.iseol | not))] | first | .version)
             end) as $latestStable
          | (if $kernels == null then []
             else [$kernels[] | select(.moniker == "longterm") | .version]
             end) as $longterm
          | (if $electronReleases[0] == null then null
             else ([$electronReleases[0][] | .version | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) | split(".")[0] | tonumber] | max)
             end) as $electronLatest
          | [ $electrons[0][]
              | (.version | split(".")[0] | tonumber) as $major
              | . + {major: $major, eol: (if $electronLatest == null then null else $major < $electronLatest - 2 end)}
            ] as $runtimes
          | (($chromeVersions[0] | .versions[0].version?) // null) as $chromeLatest
          | (if $braveReleases[0] == null then null
             else ([$braveReleases[0][]
                     | select((.draft | not) and (.prerelease | not) and ((.name // "") | startswith("Release v")))]
                   | first | .tag_name // null | if . == null then null else ltrimstr("v") end)
             end) as $braveLatest
          | [ $browsers[0][]
              | (if .name == "brave" then $braveLatest else $chromeLatest end) as $latest
              | . + {latest: $latest, behind: (if $latest == null then null else (.version | vkey) < ($latest | vkey) end)}
            ] as $browserRows
          | ([$runtimes[] | select(.eol == true)] | length) as $electronEol
          | ([$browserRows[] | select(.behind == true)] | length) as $browsersBehind
          | ($systemKernel != "" and $systemKernel != $runningKernel) as $rebootPending
          | {
              status: (
                if ($ageDays != null and $ageDays >= $alertDays) or $kernelEol == true or $electronEol > 0 then "alert"
                elif ($ageDays != null and $ageDays >= $warnDays) or $browsersBehind > 0 or $rebootPending then "warn"
                elif $ageDays == null then "unknown"
                else "ok"
                end
              ),
              nixpkgs: {version: $nixosVersion, date: $nixpkgs.date, rev: $nixpkgs.rev, ageDays: $ageDays},
              kernel: {
                running: $runningKernel,
                system: (if $systemKernel == "" then null else $systemKernel end),
                series: $series,
                eol: $kernelEol,
                rebootPending: $rebootPending,
                latestStable: $latestStable,
                longterm: $longterm
              },
              electron: {latestMajor: $electronLatest, eolCount: $electronEol, runtimes: $runtimes},
              browsers: $browserRows,
              unreachable: ($unreachable | split("\n") | map(select(length > 0)))
            }
        ' > "$work_dir/lag.json"

      finished_epoch="$(date -u +%s)"
      jq -n \
        --arg generatedAt "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        --argjson generatedAtEpoch "$finished_epoch" \
        --argjson durationSeconds "$((finished_epoch - started_epoch))" \
        --arg targetPath "$target_path" \
        --arg storePath "$target_store_path" \
        --arg name "$target_name" \
        --arg grype "${pkgs.grype.version}" \
        --arg govulncheck "${pkgs.govulncheck.version}" \
        --arg sbomnix "${pkgs.sbomnix.version}" \
        --slurpfile cve "$work_dir/cve.json" \
        --slurpfile go "$work_dir/go.json" \
        --slurpfile lag "$work_dir/lag.json" \
        '
          def rank:
            if . == "error" then 4
            elif . == "alert" then 3
            elif . == "warn" or . == "missing" then 2
            elif . == "ok" then 0
            else 1
            end;
          {
            schema: 2,
            generatedAt: $generatedAt,
            generatedAtEpoch: $generatedAtEpoch,
            durationSeconds: $durationSeconds,
            target: {path: $targetPath, storePath: $storePath, name: $name},
            tools: {grype: $grype, govulncheck: $govulncheck, sbomnix: $sbomnix},
            checks: {cve: $cve[0], go: $go[0], lag: $lag[0]},
            status: ([$cve[0].status, $go[0].status, $lag[0].status] | max_by(rank))
          }
        ' > "$work_dir/status.json"
      mv "$work_dir/status.json" "$status_file"
      status_written=1

      if jq -e '[.checks[].status] | index("error") != null' "$status_file" > /dev/null; then
        exit 1
      fi
    '';
  };
  nixVulnStatusLabelScript = lib.getExe (pkgs.writeShellApplication {
    name = "nix-vuln-status-label";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.systemd
    ];
    text = ''
      set -euo pipefail

      cache_file="''${XDG_CACHE_HOME:-$HOME/.cache}/nix-vuln-status/status.json"
      state="$(systemctl --user show --property ActiveState --value nix-vuln-status.service 2> /dev/null || true)"

      running=""
      if [ "$state" = "activating" ]; then
        running=' <span foreground="#8aadf4">󰑓</span>'
      fi

      if [ ! -s "$cache_file" ] || ! jq -e '.schema == 2' "$cache_file" > /dev/null 2>&1; then
        printf '<span foreground="#a5adcb">VULN --</span>%s\n' "$running"
        exit 0
      fi

      jq -r \
        --argjson nowEpoch "$(date -u +%s)" \
        --argjson staleSeconds ${builtins.toString vulnStatusStaleSeconds} \
        --arg running "$running" \
        '
          ${vulnStatusStatusColor}
          def segment($label; $check; $value):
            "<span foreground=\"" + (($check.status // "unknown") | color) + "\">" + $label + " " + $value + "</span>";
          (.checks.cve // {}) as $cve
          | (.checks.go // {}) as $go
          | (.checks.lag // {}) as $lag
          | (.generatedAtEpoch // 0) as $generatedEpoch
          | if (.checks | length) == 0 then
              "<span foreground=\"#ed8796\">VULN ERR</span>" + $running
            else
              [
                segment("CVE"; $cve;
                  if $cve.status == "missing" then "?"
                  elif $cve.status == "error" then "!"
                  else ($cve.count // 0 | tostring)
                  end),
                segment("GO"; $go;
                  if $go.status == "error" then "!"
                  else ($go.count // 0 | tostring)
                  end),
                segment("NIX"; $lag;
                  if $lag.nixpkgs.ageDays == null then "?"
                  else "\($lag.nixpkgs.ageDays)d"
                  end)
              ]
              | join("<span foreground=\"#6e738d\"> · </span>")
              | . + (if ($nowEpoch - $generatedEpoch) > $staleSeconds then " <span foreground=\"#eed49f\">OLD</span>" else "" end)
              | . + $running
            end
        ' "$cache_file"
    '';
  });
  nixVulnStatusDetailsScript = lib.getExe (pkgs.writeShellApplication {
    name = "nix-vuln-status-details";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.systemd
    ];
    text = ''
      set -euo pipefail

      cache_file="''${XDG_CACHE_HOME:-$HOME/.cache}/nix-vuln-status/status.json"
      state="$(systemctl --user show --property ActiveState --value nix-vuln-status.service 2> /dev/null || true)"

      if [ ! -s "$cache_file" ] || ! jq -e '.schema == 2' "$cache_file" > /dev/null 2>&1; then
        if [ "$state" = "activating" ]; then
          printf 'Scanning now. The first run takes a few minutes.\n'
        else
          printf 'No results yet. Press Rescan to run the checks.\n'
        fi
        exit 0
      fi

      jq -r \
        --argjson nowEpoch "$(date -u +%s)" \
        --argjson staleSeconds ${builtins.toString vulnStatusStaleSeconds} \
        --argjson limit ${builtins.toString vulnStatusDisplayLimit} \
        --arg state "$state" \
        '
          ${vulnStatusStatusColor}
          def esc: tostring | @html;
          def pad($width): tostring | if length >= $width then . else . + (" " * ($width - length)) end;
          def tag($status; $text): "<span foreground=\"" + ($status | color) + "\">" + $text + "</span>";
          def ago($epoch):
            (($nowEpoch - $epoch) | if . < 0 then 0 else . end) as $age
            | if $age >= 86400 then "\(($age / 86400) | floor)d"
              elif $age >= 3600 then "\(($age / 3600) | floor)h"
              elif $age >= 60 then "\(($age / 60) | floor)m"
              else "\($age)s"
              end;
          def when($epoch): ($epoch | strflocaltime("%Y-%m-%d %H:%M")) + " (" + ago($epoch) + " ago)";
          def duration($seconds):
            if $seconds >= 60 then "\(($seconds / 60) | floor)m\($seconds % 60)s" else "\($seconds)s" end;
          def date8: if . == null then "unknown" else .[0:4] + "-" + .[4:6] + "-" + .[6:8] end;
          (.checks.cve // {}) as $cve
          | (.checks.go // {}) as $go
          | (.checks.lag // {}) as $lag
          | if (.checks | length) == 0 then
              tag("error"; "Scan failed") + "  " + ((.error // "unknown error") | esc),
              "Checked  " + when(.generatedAtEpoch // 0)
            else
              "Checked  " + when(.generatedAtEpoch // 0) + ", took " + duration(.durationSeconds // 0)
                + (if ($nowEpoch - (.generatedAtEpoch // 0)) > $staleSeconds then "  " + tag("warn"; "stale") else "" end),
              (if $state == "activating" then "Status   " + tag("unknown"; "scanning now") else empty end),
              "System   " + ((.target.name // "unknown") | esc),
              "",
              tag($cve.status // "unknown"; "CVE") + "  sbomnix + grype   "
                + (if $cve.status == "missing" then tag("missing"; "no SBOM")
                   elif $cve.status == "error" then tag("error"; "failed")
                   else tag($cve.status; "\($cve.count) found")
                     + " in \($cve.matches // $cve.count) package matches (critical \($cve.bySeverity.Critical // 0), high \($cve.bySeverity.High // 0))"
                   end),
              (if $cve.status == "missing" or $cve.status == "error" then
                 "     " + (($cve.message // "") | esc)
               else
                 "     scope    \($cve.coverage.withCpe) of \($cve.coverage.components) packages have an exact CPE",
                 "     SBOM     " + (if $cve.sbom.generatedAtEpoch == null then "unknown" else when($cve.sbom.generatedAtEpoch) end),
                 "     skipped  \($cve.excluded.noVersionRange) without a version range, \($cve.excluded.patched) patched, \($cve.excluded.reviewed // 0) reviewed",
                 ($cve.packages[:$limit][] | "     " + ("\(.package) \(.version)" | esc | pad(32)) + " \(.count)")
               end),
              "",
              tag($go.status // "unknown"; "GO ") + "  govulncheck       "
                + (if $go.status == "error" then tag("error"; "failed")
                   else tag($go.status; "\($go.count) found") + " in \($go.affectedBinaries) of \($go.binaries) Go binaries"
                   end),
              (if $go.status == "error" then
                 "     " + (($go.message // "") | esc)
               else
                 "     scope    stdlib \($go.stdlib), modules \($go.modules)"
                   + (if ($go.failed // 0) > 0 then ", \($go.failed) binaries could not be read" else "" end),
                 ($go.binariesTop[:$limit][] | "     " + (.name | esc | pad(32)) + " \(.count)")
               end),
              "",
              tag($lag.status // "unknown"; "NIX") + "  update lag        "
                + (if $lag.nixpkgs.ageDays == null then tag("unknown"; "nixpkgs date unknown")
                   else tag($lag.status; "nixpkgs \($lag.nixpkgs.date | date8), \($lag.nixpkgs.ageDays) days old")
                   end),
              "     kernel   " + ($lag.kernel.running | esc) + "  "
                + (if $lag.kernel.eol == true then tag("alert"; "end of life")
                   elif $lag.kernel.eol == false then tag("ok"; "maintained")
                   else tag("unknown"; "unknown")
                   end)
                + (if $lag.kernel.latestStable != null then "  (stable \($lag.kernel.latestStable))" else "" end)
                + (if $lag.kernel.rebootPending == true then "  " + tag("warn"; "reboot pending") else "" end),
              ($lag.electron.runtimes // [] | .[]
                | "     electron " + (.version | pad(9)) + " "
                  + (if .eol == true then tag("alert"; "end of life") elif .eol == false then tag("ok"; "supported  ") else "unknown    " end)
                  + "  " + (.apps | join(", ") | esc)),
              ($lag.browsers // [] | .[]
                | "     " + (.name | pad(14)) + (.version | esc)
                  + (if .behind == true then " -> " + tag("warn"; .latest | esc)
                     elif .behind == false then "  " + tag("ok"; "latest")
                     else ""
                     end)),
              (if ($lag.unreachable // [] | length) > 0 then
                 "     " + tag("unknown"; "unreachable: " + ($lag.unreachable | map(sub("^https://"; "") | split("/")[0]) | unique | join(", ")))
               else empty
               end),
              "",
              "Not checked: ~/.nix-profile, ~/.local/bin, Docker images"
            end
        ' "$cache_file"
    '';
  });
  nixVulnStatusTriggerScript = lib.getExe (pkgs.writeShellApplication {
    name = "nix-vuln-status-trigger";
    runtimeInputs = [
      pkgs.systemd
    ];
    text = ''
      set -euo pipefail

      systemctl --user start --no-block nix-vuln-status.service
    '';
  });
  keepAwakeControl = pkgs.writeShellApplication {
    name = "keep-awake";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      set -euo pipefail

      service_name="inhibit-idle-sleep.service"
      config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/hq"
      allow_sleep_flag="$config_dir/allow-sleep"

      is_active() {
        systemctl --user is-active --quiet "$service_name"
      }

      is_failed() {
        systemctl --user is-failed --quiet "$service_name"
      }

      print_label() {
        if is_active; then
          printf '<span font-size="18pt" foreground="#a6da95"></span>\n'
        elif [ -e "$allow_sleep_flag" ]; then
          printf '<span font-size="18pt" foreground="#a5adcb"></span>\n'
        elif is_failed; then
          printf '<span font-size="18pt" foreground="#ed8796"></span>\n'
        else
          printf '<span font-size="18pt" foreground="#eed49f"></span>\n'
        fi
      }

      enable_keep_awake() {
        rm -f "$allow_sleep_flag"
        systemctl --user start "$service_name"
      }

      disable_keep_awake() {
        mkdir -p "$config_dir"
        : > "$allow_sleep_flag"
        systemctl --user stop "$service_name"
      }

      case "''${1:-toggle}" in
        on)
          enable_keep_awake
          ;;
        off)
          disable_keep_awake
          ;;
        toggle)
          if is_active; then
            disable_keep_awake
          else
            enable_keep_awake
          fi
          ;;
        status)
          if is_active; then
            printf 'enabled\n'
          elif [ -e "$allow_sleep_flag" ]; then
            printf 'allow-sleep\n'
          elif is_failed; then
            printf 'failed\n'
          else
            printf 'inactive\n'
          fi
          ;;
        status-label)
          print_label
          ;;
        *)
          printf 'usage: keep-awake [on|off|toggle|status|status-label]\n' >&2
          exit 2
          ;;
      esac
    '';
  };
  keepAwakeScript = lib.getExe keepAwakeControl;
  mkValueModule =
    { name
    , icon
    , script
    , interval
    ,
    }: {
      type = "custom";
      inherit name;
      class = "value-module";
      bar = [
        {
          type = "box";
          name = "${name}-box";
          class = "value-module-box";
          widgets = [
            {
              type = "label";
              name = "${name}-icon";
              class = "value-module-icon";
              label = icon;
            }
            {
              type = "label";
              name = "${name}-value";
              class = "value-module-value";
              label = "{{${builtins.toString interval}:${script}}}";
            }
          ];
        }
      ];
    };
  mkProcessCountScript = name: matchNames:
    lib.getExe (pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gawk
        pkgs.procps
      ];
      text = ''
        current_user="$(id -un)"

        ps -u "$current_user" -o comm= | awk '
          BEGIN {
            split("${lib.concatStringsSep " " matchNames}", names, " ")
            for (i in names) {
              watched[names[i]] = 1
            }
          }

          watched[$1] {
            count += 1
          }

          END {
            printf "%d\n", count + 0
          }
        '
      '';
    });
  codexProcessCountScript = mkProcessCountScript "ironbar-codex-process-count" [
    ".codex-real"
    "codex"
  ];
  claudeProcessCountScript = mkProcessCountScript "ironbar-claude-process-count" [
    ".claude-real"
    "claude"
  ];
  aiProcessesModule = {
    type = "custom";
    name = "ai-processes";
    class = "ai-processes";
    bar = [
      {
        type = "box";
        name = "ai-processes-box";
        class = "ai-processes-box";
        widgets = [
          {
            type = "box";
            name = "codex-process";
            class = "ai-process";
            widgets = [
              {
                type = "image";
                name = "codex-icon";
                src = "file://${codexIcon}";
                size = 8;
              }
              {
                type = "label";
                name = "codex-count";
                class = "ai-process-count";
                label = "{{3000:${codexProcessCountScript}}}";
              }
            ];
          }
          {
            type = "box";
            name = "claude-process";
            class = "ai-process";
            widgets = [
              {
                type = "image";
                name = "claude-icon";
                src = "file://${claudeIcon}";
                size = 16;
              }
              {
                type = "label";
                name = "claude-count";
                class = "ai-process-count";
                label = "{{3000:${claudeProcessCountScript}}}";
              }
            ];
          }
        ];
      }
    ];
  };

  displayLayout = import ./display-layout.nix;
  workspaceSlots = lib.range 1 displayLayout.workspacesPerMonitor;
  leftWorkspaceTarget = { role = "left"; description = displayLayout.hq.left; };
  rightWorkspaceTarget = { role = "right"; description = displayLayout.hq.right; };
  primaryWorkspaceTarget = { role = "primary"; monitorId = 0; };
  secondaryWorkspaceTarget = { role = "secondary"; monitorId = 1; };
  workspaceTargets =
    if hostname == "hq" then
      [ leftWorkspaceTarget rightWorkspaceTarget ]
    else
      [ primaryWorkspaceTarget secondaryWorkspaceTarget ];
  workspaceDigits = map builtins.toString (lib.range 1 9) ++ [ "0" ];
  workspaceDisplayDigit = slot: builtins.elemAt workspaceDigits (slot - 1);
  workspaceSuffixVar = role: slot: "workspace_${role}_${builtins.toString slot}_suffix";
  workspaceModuleName = role: slot: "workspace-${role}-${builtins.toString slot}";
  workspaceClick =
    target: slot:
    let
      slotText = builtins.toString slot;
      batch = "dispatch focusmonitor desc:${target.description}; dispatch split:workspace ${slotText}";
      workspace = target.monitorId * displayLayout.workspacesPerMonitor + slot;
    in
    if target ? description then
      "!${hyprctlBin} --batch ${lib.escapeShellArg batch}"
    else
      "!${hyprctlBin} dispatch workspace ${builtins.toString workspace}";
  mkWorkspaceModule = target: slot: {
    type = "custom";
    name = workspaceModuleName target.role slot;
    class = "workspace-pill";
    bar = [
      {
        type = "button";
        class = "workspace-button";
        justify = "center";
        on_click = workspaceClick target slot;
        # Keep each segment valid while cached variables initialize. / キャッシュ変数の初期化中も各断片が有効なマークアップになるようにする。
        label = "<span weight=\"800\">${workspaceDisplayDigit slot}</span>\n#${workspaceSuffixVar target.role slot}";
      }
    ];
  };
  primaryWorkspaceModules = map (mkWorkspaceModule primaryWorkspaceTarget) workspaceSlots;
  secondaryWorkspaceModules = map (mkWorkspaceModule secondaryWorkspaceTarget) workspaceSlots;
  leftWorkspaceModules = map (mkWorkspaceModule leftWorkspaceTarget) workspaceSlots;
  rightWorkspaceModules = map (mkWorkspaceModule rightWorkspaceTarget) workspaceSlots;

  mkFocused = maxLength: {
    type = "focused";
    name = "focused-window";
    icon_size = 18;
    justify = "center";
    show_icon = true;
    show_title = true;
    truncate = {
      mode = "end";
      max_length = maxLength;
    };
  };

  musicModule = {
    type = "music";
    name = "music";
    player_type = "mpris";
    format = "{title}";
    show_status_icon = true;
    truncate = {
      mode = "end";
      max_length = 34;
    };
    icons = {
      play = "";
      pause = "";
      prev = "󰒮";
      next = "󰒭";
      volume = "󰕾";
      track = "󰎈";
      album = "󰀥";
      artist = "󰠃";
    };
  };

  cpuModule = mkValueModule {
    name = "cpu";
    icon = "";
    script = cpuUsageScript;
    interval = 1000;
  };
  memoryModule = mkValueModule {
    name = "memory";
    icon = "󰍛";
    script = memoryUsageScript;
    interval = 5000;
  };
  diskModule = mkValueModule {
    name = "disk";
    icon = "󰋊";
    script = diskUsageScript;
    interval = 30000;
  };
  vulnStatusModule = {
    type = "custom";
    name = "vuln-status";
    class = "vuln-status";
    tooltip = "CVE: sbomnix + grype, GO: govulncheck, NIX: days since the nixpkgs revision. Click for details, right-click to rescan.";
    bar = [
      {
        type = "button";
        name = "vuln-status-trigger";
        label = "{{10000:${nixVulnStatusLabelScript}}}";
        on_click = "popup:toggle";
        on_click_right = "!${nixVulnStatusTriggerScript}";
      }
    ];
    popup = [
      {
        type = "box";
        name = "vuln-status-popup";
        orientation = "vertical";
        widgets = [
          {
            type = "label";
            name = "vuln-status-heading";
            label = "Vulnerability Checks";
          }
          {
            type = "label";
            name = "vuln-status-details";
            label = "{{30000:${nixVulnStatusDetailsScript}}}";
          }
          {
            type = "button";
            name = "vuln-status-refresh";
            label = "Rescan";
            on_click = "!${nixVulnStatusTriggerScript}";
          }
        ];
      }
    ];
  };

  volumeModule = {
    type = "volume";
    name = "volume";
    format = "{icon} {percentage}%";
    max_volume = 100;
    truncate = "middle";
    icons = {
      volume_high = "󰕾";
      volume_medium = "󰖀";
      volume_low = "󰕿";
      muted = "󰝟";
      mic_volume = "";
      mic_muted = "";
    };
    on_click_right = "${pkgs.pavucontrol}/bin/pavucontrol";
  };

  networkModule = {
    type = "network_manager";
    name = "network";
    icon_size = 18;
    types_blacklist = [
      "loopback"
      "bridge"
    ];
  };

  bluetoothModule = {
    type = "bluetooth";
    name = "bluetooth";
    icon_size = 18;
    format = {
      not_found = "";
      disabled = "󰂲";
      enabled = "󰂯";
      connected = "󰂱 {device_alias}";
      connected_battery = "󰂱 {device_alias} {device_battery_percent}%";
    };
    popup = {
      max_height = {
        devices = 6;
      };
      header = "Bluetooth";
    };
  };

  batteryModule = {
    type = "battery";
    name = "battery";
    format = "{percentage}%";
    show_icon = true;
    show_label = true;
    thresholds = {
      warning = 25;
      critical = 10;
    };
  };

  notificationsModule = {
    type = "notifications";
    name = "notifications";
    show_count = false;
    icons = {
      closed_none = "󰍥";
      closed_some = "󱥂";
      closed_dnd = "󱅯";
      open_none = "󰍡";
      open_some = "󱥁";
      open_dnd = "󱅮";
    };
  };

  trayModule = {
    type = "tray";
    name = "tray";
    icon_size = 18;
    prefer_theme_icons = true;
  };

  clockModule = {
    type = "clock";
    name = "clock";
    format = "%Y/%m/%d %H:%M";
    format_popup = "%H:%M:%S";
    locale = "ja_JP";
  };

  powerMenuModule = {
    type = "custom";
    name = "power-menu";
    class = "power-menu";
    tooltip = "Session controls";
    bar = [
      {
        type = "button";
        name = "power-trigger";
        label = "";
        on_click = "popup:toggle";
      }
    ];
    popup = [
      {
        type = "box";
        name = "power-popup";
        orientation = "vertical";
        widgets = [
          {
            type = "label";
            name = "power-heading";
            label = "Session";
          }
          {
            type = "box";
            class = "power-actions";
            widgets = [
              {
                type = "button";
                name = "keep-awake-toggle";
                class = "power-action";
                label = "{{1000:${keepAwakeScript} status-label}}";
                on_click = "!${keepAwakeScript} toggle";
              }
              {
                type = "button";
                class = "power-action";
                label = "<span font-size='18pt'>󰤄</span>";
                on_click = "!${systemctlBin} suspend";
              }
              {
                type = "button";
                class = "power-action";
                label = "<span font-size='18pt'>󰜉</span>";
                on_click = "!${hyprctlBin} dispatch exit";
              }
              {
                type = "button";
                class = "power-action";
                label = "<span font-size='18pt'></span>";
                on_click = "!${systemctlBin} reboot";
              }
              {
                type = "button";
                class = "power-action";
                label = "<span font-size='18pt'></span>";
                on_click = "!${systemctlBin} poweroff";
              }
            ];
          }
          {
            type = "label";
            name = "power-uptime";
            label = "Up {{30000:uptime -p | cut -d ' ' -f2-}}";
          }
        ];
      }
    ];
  };

  barDefaults = {
    anchor_to_edges = true;
    exclusive_zone = true;
    icon_theme = "Papirus";
    layer = "top";
    popup_gap = 10;
    position = "top";
  };

  desktopStart = if hostname == "hq" then leftWorkspaceModules else primaryWorkspaceModules;
  compactStart = if hostname == "hq" then rightWorkspaceModules else primaryWorkspaceModules;
  desktopCenter = [ (mkFocused 42) ];

  workspaceStateScript = lib.getExe (pkgs.writeShellApplication {
    name = "ironbar-workspace-state";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.ironbar
      pkgs.jq
      pkgs.socat
    ];
    text = ''
      set -eu

      export PATH="/run/current-system/sw/bin:$HOME/.nix-profile/bin:$PATH"

      declare -A last_vars=()
      declare -A last_classes=()

      ironbar_ipc_timeout=3
      ironbar_ready_attempts=20

      ironbar_ipc() {
        timeout "''${ironbar_ipc_timeout}s" ironbar "$@"
      }

      wait_for_ironbar() {
        for _ in $(seq 1 "$ironbar_ready_attempts"); do
          if ironbar_ipc ping >/dev/null 2>&1; then
            return 0
          fi

          sleep 1
        done

        printf 'Ironbar did not answer IPC ping within %s seconds\n' \
          "$((ironbar_ready_attempts * (ironbar_ipc_timeout + 1)))" >&2
        return 1
      }

      find_hypr_socket() {
        local runtime_dir signature candidate best best_mtime mtime

        runtime_dir="''${XDG_RUNTIME_DIR-}"
        signature="''${HYPRLAND_INSTANCE_SIGNATURE-}"
        if [ -z "$runtime_dir" ]; then
          runtime_dir="/run/user/$UID"
        fi

        best=""
        best_mtime=0

        if [ -n "$signature" ]; then
          candidate="$runtime_dir/hypr/$signature/.socket2.sock"
          if [ -S "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
          fi
        fi

        for candidate in "$runtime_dir"/hypr/*/.socket2.sock; do
          [ -S "$candidate" ] || continue

          mtime="$(stat -c '%Y' "$candidate" 2>/dev/null || printf '0')"
          if [ "$mtime" -ge "$best_mtime" ]; then
            best="$candidate"
            best_mtime="$mtime"
          fi
        done

        [ -n "$best" ] || return 1
        printf '%s\n' "$best"
      }

      set_var_if_changed() {
        local key value current

        key="$1"
        value="$2"
        current="__missing__"
        if [ -v "last_vars[$key]" ]; then
          current="''${last_vars[$key]}"
        fi

        [ "$current" = "$value" ] && return 0

        if ironbar_ipc var set "$key" "$value" >/dev/null 2>&1; then
          last_vars["$key"]="$value"
          return 0
        fi

        return 1
      }

      set_class_if_changed() {
        local module_name class_name desired key current

        module_name="$1"
        class_name="$2"
        desired="$3"
        key="$module_name:$class_name"
        current="__missing__"
        if [ -v "last_classes[$key]" ]; then
          current="''${last_classes[$key]}"
        fi

        [ "$current" = "$desired" ] && return 0

        if [ "$desired" = "1" ]; then
          if ironbar_ipc style add-class "$module_name" "$class_name" >/dev/null 2>&1; then
            last_classes["$key"]="$desired"
            return 0
          fi
        else
          if ironbar_ipc style remove-class "$module_name" "$class_name" >/dev/null 2>&1; then
            last_classes["$key"]="$desired"
            return 0
          fi
        fi

        return 1
      }

      build_suffix() {
        local app_count has_brave dot_count suffix

        app_count="$1"
        has_brave="$2"

        if [ "$app_count" -le 0 ]; then
          printf '%s' ""
          return 0
        fi

        dot_count="$app_count"
        if [ "$dot_count" -gt 3 ]; then
          dot_count=3
        fi

        case "$dot_count:$has_brave" in
          1:0)
            suffix="•"
            ;;
          1:1)
            suffix="<span foreground=\"#f5a97f\">•</span>"
            ;;
          2:0)
            suffix="••"
            ;;
          2:1)
            suffix="<span foreground=\"#f5a97f\">•</span>•"
            ;;
          3:0)
            suffix="•••"
            ;;
          3:1)
            suffix="<span foreground=\"#f5a97f\">•</span>••"
            ;;
          *)
            suffix=""
            ;;
        esac

        printf '<span size="smaller">%s</span>' "$suffix"
      }

      should_refresh_for_event() {
        local event_name

        event_name="$1"
        case "$event_name" in
          workspace*|focusedmon*|monitoradded*|monitorremoved*|movewindow*|openwindow*|closewindow*|createworkspace*|destroyworkspace*|renameworkspace*)
            return 0
            ;;
          *)
            return 1
            ;;
        esac
      }

      update_state() {
        local clients_json monitors_json rows role slot count has_brave focused suffix module_name

        clients_json="$(hyprctl clients -j 2>/dev/null)" || return 1
        monitors_json="$(hyprctl monitors -j 2>/dev/null)" || return 1

        rows="$(
          jq -nr \
            --argjson clients "$clients_json" \
            --argjson monitors "$monitors_json" \
            --argjson targets ${lib.escapeShellArg (builtins.toJSON workspaceTargets)} \
            --argjson workspace_count ${builtins.toString displayLayout.workspacesPerMonitor} \
            '
              def app_id: (.class // .initialClass // .title // .address // "unknown") | ascii_downcase;
              def is_brave: ((.class // .initialClass // "") | ascii_downcase | contains("brave"));
              def is_quick_term: ((.class // .initialClass // "") | test("^com\\.mitchellh\\.ghostty\\.quick\\.(left|right)$"));
              def stats:
                reduce ($clients[] | select((.workspace.id // 0) > 0 and (is_quick_term | not))) as $client
                  ({};
                    .[($client.workspace.id | tostring)] = (
                      (.[($client.workspace.id | tostring)] // { apps: [], brave: false })
                      | .apps += [($client | app_id)]
                      | .brave = (.brave or ($client | is_brave))
                    )
                  );
              def monitor_for($target):
                if ($target | has("description")) then
                  first($monitors[] | select(.description | startswith($target.description))) // null
                else
                  first($monitors[] | select(.id == $target.monitorId)) // null
                end;
              def rows_for($target; $stats):
                (monitor_for($target)) as $monitor
                | if $monitor == null then
                    range(1; $workspace_count + 1)
                    | [$target.role, ., 0, 0, 0]
                  else
                    ($monitor.id * $workspace_count) as $base
                    | range(1; $workspace_count + 1) as $slot
                    | ($base + $slot) as $workspace
                    | ($stats[($workspace | tostring)] // { apps: [], brave: false }) as $state
                    | [
                        $target.role,
                        $slot,
                        ($state.apps | unique | length),
                        (if $state.brave then 1 else 0 end),
                        (if $monitor.activeWorkspace.id == $workspace then 1 else 0 end)
                      ]
                  end;
              (stats) as $stats
              | $targets[]
              | rows_for(.; $stats)
              | @tsv
            '
        )" || return 1

        while IFS=$'\t' read -r role slot count has_brave focused; do
          [ -n "$role" ] || continue

          suffix="$(build_suffix "$count" "$has_brave")" || return 1
          set_var_if_changed "workspace_''${role}_''${slot}_suffix" "$suffix" || return 1

          module_name="workspace-$role-$slot"
          set_class_if_changed "$module_name" "focused" "$focused" || return 1
        done <<< "$rows"
      }

      while true; do
        if ! command -v hyprctl >/dev/null 2>&1; then
          sleep 2
          continue
        fi

        wait_for_ironbar

        socket_path=""
        if ! socket_path="$(find_hypr_socket)"; then
          sleep 1
          continue
        fi

        if ! update_state; then
          sleep 1
          continue
        fi

        while read -r _event; do
          event_name="''${_event%%>>*}"

          if ! should_refresh_for_event "$event_name"; then
            continue
          fi

          if ! ironbar_ipc ping >/dev/null 2>&1; then
            break
          fi

          case "$event_name" in
            monitoradded*|monitorremoved*)
              last_classes=()
              ;;
          esac

          if ! update_state; then
            break
          fi
        done < <(socat -u "UNIX-CONNECT:$socket_path" - 2>/dev/null)

        sleep 1
      done
    '';
  });

  desktopEnd =
    [
      musicModule
      aiProcessesModule
      vulnStatusModule
      cpuModule
      memoryModule
      diskModule
      volumeModule
      bluetoothModule
    ]
    ++ lib.optional hasBattery batteryModule
    ++ [
      notificationsModule
      trayModule
      clockModule
      powerMenuModule
    ];

  compactEnd =
    [
      aiProcessesModule
      vulnStatusModule
      cpuModule
      memoryModule
      diskModule
      volumeModule
      bluetoothModule
    ]
    ++ lib.optional hasBattery batteryModule
    ++ [ powerMenuModule ];

  defaultBar = barDefaults // {
    name = "ironbar-default";
    height = 40;
    margin = {
      top = 8;
      left = 12;
      right = 12;
      bottom = 0;
    };
    start = desktopStart;
    center = desktopCenter;
    end = desktopEnd;
  };

  compactBar = barDefaults // {
    name = if hostname == "hq" then "ironbar-right" else "ironbar-dp2";
    height = 36;
    margin = {
      top = 8;
      left = 8;
      right = 8;
      bottom = 0;
    };
    start = compactStart;
    center = if hostname == "hq" then [ ] else [ (mkFocused 18) ];
    end = compactEnd;
  };

  ironbarConfig = defaultBar // {
    monitors =
      if hostname == "hq" then {
        "${displayLayout.hq.left}" = defaultBar;
        "${displayLayout.hq.right}" = compactBar;
      } else {
        "DP-2" = compactBar;
        "DP-3" = defaultBar // {
          name = "ironbar-dp3";
          start = secondaryWorkspaceModules;
        };
      };
  };
in
{
  home.packages = [
    pkgs.ironbar
    keepAwakeControl
    nixVulnStatusRefresh
    # switch-hq runs this from the system it is deploying.
    nixVulnStatusSbom
    (pkgs.writeShellApplication {
      name = "ironbar-toggle-power-menu";
      runtimeInputs = [
        pkgs.ironbar
        pkgs.jq
      ];
      text = ''
        bar_name="ironbar-default"
        active_monitor="$(${hyprctlBin} monitors -j | jq -ce 'first(.[] | select(.focused == true))')"

        ${if hostname == "hq" then ''
          right_description=${lib.escapeShellArg displayLayout.hq.right}
          active_description="$(printf '%s\n' "$active_monitor" | jq -er '.description')"

          case "$active_description" in
            "$right_description"*)
              bar_name="ironbar-right"
              ;;
          esac
        '' else ''
          active_name="$(printf '%s\n' "$active_monitor" | jq -er '.name')"
          case "$active_name" in
            DP-2) bar_name="ironbar-dp2" ;;
            DP-3) bar_name="ironbar-dp3" ;;
          esac
        ''}

        exec ironbar bar "$bar_name" toggle-popup power-menu
      '';
    })
  ];

  xdg.configFile."ironbar/config.json" = {
    force = true;
    text = builtins.toJSON ironbarConfig;
  };

  xdg.configFile."ironbar/style.css" = {
    force = true;
    text = ''
      @define-color panel_bg #1e2030;
      @define-color panel_surface #24273a;
      @define-color panel_surface_alt #363a4f;
      @define-color panel_surface_alt_2 #494d64;
      @define-color panel_border #5b6078;
      @define-color panel_fg #cad3f5;
      @define-color panel_muted #a5adcb;
      @define-color panel_accent #8aadf4;
      @define-color panel_accent_soft #b7bdf8;
      @define-color panel_accent_alt #c6a0f6;
      @define-color panel_good #a6da95;
      @define-color panel_warn #eed49f;
      @define-color panel_bad #ed8796;
      @define-color panel_info #7dc4e4;
      @define-color panel_teal #8bd5ca;
      @define-color panel_peach #f5a97f;

      * {
      border: none;
      border-radius: 0;
      box-shadow: none;
      color: @panel_fg;
      font-family: "Noto Sans CJK JP", "Symbols Nerd Font", sans-serif;
      font-size: 12px;
      }

      .background {
      background: transparent;
      }

      #bar {
      background-color: alpha(@panel_bg, 0.97);
      border: 1px solid alpha(@panel_surface_alt_2, 0.96);
      border-radius: 14px;
      box-shadow: 0 16px 38px alpha(black, 0.48);
      padding: 4px 6px;
      }

      #bar #start,
      #bar #center,
      #bar #end {
      background: transparent;
      }

      #bar separator,
      #bar .separator,
      #bar undershoot,
      #bar overshoot {
      min-width: 0;
      min-height: 0;
      margin: 0;
      padding: 0;
      background: transparent;
      border: none;
      box-shadow: none;
      opacity: 0;
      }

      #bar *:focus,
      #bar *:focus-visible {
      outline: none;
      box-shadow: none;
      }

      .widget-container {
      margin: 0 3px;
      }

      .widget,
      button,
      menubutton {
      background-color: alpha(@panel_surface, 0.96);
      border: none;
      border-radius: 11px;
      min-height: 28px;
      padding: 0 10px;
      transition: background-color 160ms ease, border-color 160ms ease, color 160ms ease;
      }

      .widget:hover,
      button:hover,
      menubutton:hover {
      background-color: alpha(@panel_surface_alt, 0.98);
      }

      #power-trigger {
        background-image: linear-gradient(135deg, @panel_accent_alt, @panel_accent);
        color: @panel_bg;
        font-weight: 800;
      }

      #power-trigger:hover {
        background-image: linear-gradient(135deg, @panel_accent_soft, @panel_accent);
      }

      .workspace-pill {
      background: transparent;
      border: none;
      margin: 0;
      min-height: 0;
      padding: 0;
      }

      .workspace-pill:hover {
      background: transparent;
      }

      .workspace-pill button {
      background-color: alpha(@panel_surface, 0.94);
      border: none;
      border-radius: 9px;
      min-height: 20px;
      width: 30px;
      min-width: 30px;
      max-width: 30px;
      padding: 0;
      }

      .workspace-pill button label {
      font-size: 10px;
      line-height: 0.74;
      margin: 0;
      }

      .workspace-pill.focused button {
      background-image: linear-gradient(135deg, @panel_accent_alt, @panel_accent);
      color: @panel_bg;
      font-weight: 800;
      }

      .workspace-pill.focused button:hover {
      background-image: linear-gradient(135deg, @panel_accent_soft, @panel_accent);
      }

      #focused-window {
      min-width: 240px;
      }

      #focused-window {
      background-color: alpha(@panel_surface_alt, 0.72);
      padding-left: 16px;
      padding-right: 16px;
      }

      #music {
      min-width: 120px;
      background-image: linear-gradient(90deg, alpha(@panel_accent_alt, 0.24), alpha(@panel_accent, 0.16));
      }

      #cpu,
      #memory,
      #disk,
      #ai-processes,
      #vuln-status,
      #volume,
      #network,
      #bluetooth,
      #battery,
      #clock,
      #notifications,
      #tray,
      #power-menu {
      font-weight: 700;
      }

      #ai-processes {
      padding-left: 8px;
      padding-right: 8px;
      }

      #vuln-status {
      padding-left: 0;
      padding-right: 0;
      }

      #cpu,
      #memory,
      #disk {
      padding-left: 8px;
      padding-right: 8px;
      }

      #ai-processes,
      #ai-processes label {
      color: @panel_accent;
      }

      #ai-processes-box,
      #vuln-status-popup,
      #cpu-box,
      #memory-box,
      #disk-box,
      #codex-process,
      #claude-process {
      background: transparent;
      }

      #cpu-icon,
      #memory-icon,
      #disk-icon,
      #codex-icon,
      #claude-icon {
      margin-right: 6px;
      }

      #codex-count {
      margin-right: 12px;
      }

      #codex-count,
      #claude-count,
      #vuln-status-trigger label,
      #cpu-icon,
      #memory-icon,
      #disk-icon,
      #cpu-value,
      #memory-value,
      #disk-value {
      color: @panel_fg;
      font-weight: 400;
      }

      #vuln-status-trigger {
      background-color: alpha(@panel_surface, 0.96);
      padding-left: 10px;
      padding-right: 10px;
      }

      #vuln-status-trigger:hover {
      background-color: alpha(@panel_surface_alt, 0.98);
      }

      .popup-vuln-status {
      min-width: 360px;
      }

      .popup-vuln-status #vuln-status-heading {
      color: @panel_accent_soft;
      font-size: 16px;
      font-weight: 800;
      margin-bottom: 10px;
      }

      .popup-vuln-status #vuln-status-details {
      color: @panel_fg;
      font-family: "Noto Sans Mono CJK JP", "Symbols Nerd Font", monospace;
      font-weight: 400;
      line-height: 1.35;
      margin-bottom: 10px;
      }

      .popup-vuln-status #vuln-status-refresh {
      background-color: alpha(@panel_surface_alt, 0.98);
      color: @panel_accent_soft;
      font-weight: 800;
      }

      #volume label {
      color: @panel_info;
      }

      #network label {
      color: @panel_teal;
      }

      #bluetooth label,
      #clock label {
      color: @panel_accent_soft;
      }

      #notifications label {
      color: @panel_accent_alt;
      }

      #power-menu label {
      color: @panel_peach;
      }

      .battery.warning label {
      color: @panel_warn;
      }

      .battery.critical label {
      color: @panel_bad;
      }

      .notifications .count {
      background-color: @panel_accent_alt;
      border-radius: 999px;
      color: @panel_bg;
      font-size: 10px;
      font-weight: 800;
      margin-left: 4px;
      min-height: 18px;
      min-width: 18px;
      padding: 0 5px;
      }

      .tray {
      padding-left: 6px;
      padding-right: 6px;
      }

      .tray .item {
      margin: 0 2px;
      }

      .popup {
      background-color: alpha(@panel_bg, 0.99);
      border: 1px solid alpha(@panel_surface_alt_2, 0.96);
      border-radius: 18px;
      box-shadow: 0 22px 50px alpha(black, 0.5);
      padding: 12px;
      }

      .popup label {
      color: @panel_fg;
      }

      .popup button {
      min-height: 36px;
      }

      .popup scale trough {
      background-color: alpha(@panel_surface_alt, 0.96);
      border-radius: 999px;
      min-height: 8px;
      }

      .popup scale highlight {
      background-image: linear-gradient(90deg, @panel_accent_alt, @panel_accent);
      border-radius: 999px;
      }

      .popup scale slider {
      background-color: @panel_fg;
      border-radius: 999px;
      min-height: 18px;
      min-width: 18px;
      }

      .popup-clock .calendar-clock {
      color: @panel_accent_soft;
      font-size: 28px;
      font-weight: 800;
      margin-bottom: 12px;
      }

      .popup-clock calendar {
      background: transparent;
      color: @panel_fg;
      }

      .popup-clock calendar:selected {
      background-color: @panel_accent_alt;
      color: @panel_bg;
      }

      .popup-music .album-art {
      border-radius: 16px;
      }

      .popup-music .title label {
      font-size: 18px;
      font-weight: 800;
      }

      .popup-music .artist label,
      .popup-music .album label {
      color: @panel_muted;
      }

      .popup-volume .device-box,
      .popup-volume .app-box,
      .popup-bluetooth .device {
      background-color: alpha(@panel_surface, 0.92);
      border: 1px solid alpha(@panel_surface_alt_2, 0.72);
      border-radius: 16px;
      padding: 10px;
      }

      .popup-power-menu {
      min-width: 280px;
      }

      .popup-power-menu #power-heading {
      color: @panel_accent_soft;
      font-size: 18px;
      font-weight: 800;
      margin-bottom: 10px;
      }

      .popup-power-menu .power-actions {
      background: transparent;
      }

      .popup-power-menu .power-action {
      background-color: alpha(@panel_surface_alt, 0.98);
      border: 1px solid alpha(@panel_surface_alt_2, 0.78);
      min-height: 54px;
      min-width: 54px;
      padding: 0;
      }

      .popup-power-menu .power-action:hover {
      background-color: alpha(@panel_accent_alt, 0.18);
      border-color: alpha(@panel_accent_soft, 0.64);
      }

      .popup-power-menu #power-uptime {
      color: @panel_muted;
      margin-top: 10px;
      }
    '';
  };

  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      "control-center-layer" = "top";
      "layer-shell" = true;
      "layer-shell-cover-screen" = false;
      "fit-to-screen" = false;
      cssPriority = "user";
      "control-center-margin-top" = 56;
      "control-center-margin-right" = 14;
      "control-center-margin-bottom" = 14;
      "control-center-width" = 400;
      "control-center-height" = 700;
      "notification-2fa-action" = true;
      "notification-inline-replies" = false;
      "notification-icon-size" = 48;
      "notification-body-image-height" = 120;
      "notification-body-image-width" = 220;
      "notification-window-width" = 400;
      timeout = 4;
      "timeout-low" = 2;
      "notification-grouping" = true;
      "image-visibility" = "never";
      "transition-time" = 120;
      widgets = [
        "title"
        "dnd"
        "notifications"
      ];
      "widget-config" = {
        notifications = {
          vexpand = true;
        };
      };
      scripts = {
        "claude-code-sound-app-name" = {
          exec = "${pkgs.pipewire}/bin/pw-play --volume 0.75 ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message.oga";
          "app-name" = "^Claude Code$";
          run-on = "receive";
        };
        "claude-code-sound-summary" = {
          exec = "${pkgs.pipewire}/bin/pw-play --volume 0.75 ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message.oga";
          summary = "^Claude Code$";
          run-on = "receive";
        };
        "ghostty-sound-summary" = {
          exec = "${pkgs.pipewire}/bin/pw-play --volume 0.75 ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message.oga";
          summary = "^Ghostty$";
          run-on = "receive";
        };
        "ghostty-sound-desktop-entry" = {
          exec = "${pkgs.pipewire}/bin/pw-play --volume 0.75 ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message.oga";
          "desktop-entry" = "^com\\.mitchellh\\.ghostty(\\.quick\\.(left|right))?$";
          run-on = "receive";
        };
      };
    };
    style = ''
      * {
      all: unset;
      font-size: 14px;
      font-family: "Noto Sans CJK JP", "Symbols Nerd Font", sans-serif;
      transition: 200ms;
      }

      trough highlight {
      background: #cad3f5;
      }

      scale {
      margin: 0 7px;
      }

      scale trough {
      margin: 0rem 1rem;
      min-height: 8px;
      min-width: 70px;
      border-radius: 12.6px;
      }

      trough slider {
      margin: -10px;
      border-radius: 12.6px;
      box-shadow: 0 0 2px rgba(0, 0, 0, 0.8);
      transition: all 0.2s ease;
      background-color: #8aadf4;
      }

      trough slider:hover {
      box-shadow: 0 0 2px rgba(0, 0, 0, 0.8), 0 0 8px #8aadf4;
      }

      trough {
      background-color: #363a4f;
      }

      .notification-background {
      box-shadow: 0 0 8px 0 rgba(0, 0, 0, 0.8), inset 0 0 0 1px #494d64;
      border-radius: 12.6px;
      margin: 10px;
      background: #1e2030;
      color: #cad3f5;
      padding: 0;
      }

      .notification-background .notification {
      padding: 7px;
      border-radius: 12.6px;
      }

      .notification-background .notification.critical {
      box-shadow: inset 0 0 7px 0 #ed8796;
      }

      .notification .notification-content {
      margin: 7px;
      }

      .notification .notification-content overlay {
      margin: 4px;
      }

      .notification-content .summary {
      color: #cad3f5;
      }

      .notification-content .time {
      color: #a5adcb;
      }

      .notification-content .body {
      color: #b8c0e0;
      }

      .notification > *:last-child > * {
      min-height: 3.4em;
      }

      .notification-background .close-button {
      margin: 7px;
      padding: 2px;
      border-radius: 6.3px;
      color: #24273a;
      background-color: #ed8796;
      }

      .notification-background .close-button:hover {
      background-color: #ee99a0;
      }

      .notification-background .close-button:active {
      background-color: #f5bde6;
      }

      .notification .notification-action {
      border-radius: 7px;
      color: #cad3f5;
      box-shadow: inset 0 0 0 1px #494d64;
      margin: 4px;
      padding: 8px;
      font-size: 0.2rem;
      background-color: #363a4f;
      }

      .notification .notification-action:hover {
      background-color: #494d64;
      }

      .notification .notification-action:active {
      background-color: #5b6078;
      }

      .notification.critical progress {
      background-color: #ed8796;
      }

      .notification.low progress,
      .notification.normal progress {
      background-color: #8aadf4;
      }

      .notification progress,
      .notification trough,
      .notification progressbar {
      border-radius: 12.6px;
      padding: 3px 0;
      }

      .control-center {
      box-shadow: 0 0 8px 0 rgba(0, 0, 0, 0.8), inset 0 0 0 1px #363a4f;
      border-radius: 12.6px;
      background-color: #24273a;
      color: #cad3f5;
      padding: 14px;
      }

      .control-center .notification-background {
      border-radius: 7px;
      box-shadow: inset 0 0 0 1px #494d64;
      margin: 4px 10px;
      }

      .control-center .notification-background .notification {
      border-radius: 7px;
      }

      .control-center .notification-background .notification.low {
      opacity: 0.8;
      }

      .control-center .widget-title > label {
      color: #cad3f5;
      font-size: 1.3em;
      }

      .control-center .widget-title button {
      border-radius: 7px;
      color: #cad3f5;
      background-color: #363a4f;
      box-shadow: inset 0 0 0 1px #494d64;
      padding: 8px;
      }

      .control-center .widget-title button:hover {
      background-color: #494d64;
      }

      .control-center .widget-title button:active {
      background-color: #5b6078;
      }

      .control-center .notification-group {
      margin-top: 10px;
      }

      .control-center .notification-group:focus .notification-background {
      background-color: #363a4f;
      }

      scrollbar slider {
      margin: -3px;
      opacity: 0.8;
      }

      scrollbar trough {
      margin: 2px 0;
      }

      .widget-dnd {
      margin-top: 5px;
      border-radius: 8px;
      font-size: 1.1rem;
      }

      .widget-dnd > switch {
      font-size: initial;
      border-radius: 8px;
      background: #363a4f;
      box-shadow: none;
      }

      .widget-dnd > switch:checked {
      background: #8aadf4;
      }

      .widget-dnd > switch slider {
      background: #494d64;
      border-radius: 8px;
      }

      .widget-mpris-player {
      background: #363a4f;
      border-radius: 12.6px;
      color: #cdd6f4;
      }

      .mpris-overlay {
      background-color: #363a4f;
      opacity: 0.9;
      padding: 15px 10px;
      }

      .widget-mpris-album-art {
      -gtk-icon-size: 100px;
      border-radius: 12.6px;
      margin: 0 10px;
      }

      .widget-mpris-title {
      font-size: 1.2rem;
      color: #cad3f5;
      }

      .widget-mpris-subtitle {
      font-size: 1rem;
      color: #b8c0e0;
      }

      .widget-mpris button {
      border-radius: 12.6px;
      color: #cad3f5;
      margin: 0 5px;
      padding: 2px;
      }

      .widget-mpris button image {
      -gtk-icon-size: 1.8rem;
      }

      .widget-mpris button:hover {
      background-color: #363a4f;
      }

      .widget-mpris button:active {
      background-color: #494d64;
      }

      .widget-mpris button:disabled {
      opacity: 0.5;
      }

      .widget-menubar > box > .menu-button-bar > button > label {
      font-size: 3rem;
      padding: 0.5rem 2rem;
      }

      .widget-menubar > box > .menu-button-bar > :last-child {
      color: #ed8796;
      }

      .power-buttons button:hover,
      .powermode-buttons button:hover,
      .screenshot-buttons button:hover {
      background: #363a4f;
      }

      .control-center .widget-label > label {
      color: #cad3f5;
      font-size: 2rem;
      }

      .widget-buttons-grid {
      padding-top: 1rem;
      }

      .widget-buttons-grid > flowbox > flowboxchild > button label {
      font-size: 2.5rem;
      }

      .widget-volume {
      padding: 1rem 0;
      }

      .widget-volume label {
      color: #7dc4e4;
      padding: 0 1rem;
      }

      .widget-volume trough highlight {
      background: #7dc4e4;
      }

      .widget-backlight trough highlight {
      background: #eed49f;
      }

      .widget-backlight label {
      font-size: 1.5rem;
      color: #eed49f;
      }

      .widget-backlight .KB {
      padding-bottom: 1rem;
      }

      .image {
      padding-right: 0.5rem;
      }
    '';
  };

  home.activation.stopHyprpanel = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${systemctlBin} --user stop hyprpanel.service 2>/dev/null || true
  '';

  home.activation.stopBluemanApplet = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${systemctlBin} --user stop 'app-blueman@autostart.service' blueman-applet.service 2>/dev/null || true
  '';

  xdg.configFile."autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Blueman Applet
    Hidden=true
  '';

  systemd.user.services.nix-vuln-status = {
    Unit = {
      Description = "Refresh Nix vulnerability scan summary";
    };

    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe nixVulnStatusRefresh;
      Nice = 10;
      IOSchedulingClass = "idle";
      TimeoutStartSec = "30min";
    };
  };

  systemd.user.timers.nix-vuln-status = {
    Unit = {
      Description = "Refresh Nix vulnerability scan summary periodically";
    };

    Timer = {
      OnBootSec = "20min";
      OnUnitActiveSec = "24h";
      Persistent = true;
      RandomizedDelaySec = "2h";
    };

    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  systemd.user.services.ironbar = {
    Unit = {
      Description = "Ironbar status bar";
      Documentation = "https://github.com/JakeStanger/ironbar/wiki";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
      X-Restart-Triggers = [
        "${config.xdg.configFile."ironbar/config.json".source}"
        "${config.xdg.configFile."ironbar/style.css".source}"
        ironbarStartScript
        ironbarHealthScript
        setDefaultSinkScript
      ];
    };

    Service = {
      Environment = [
        "IRONBAR_CONFIG=%h/.config/ironbar/config.json"
        "IRONBAR_CSS=%h/.config/ironbar/style.css"
        "IRONBAR_LOG=warn"
        "IRONBAR_FILE_LOG=warn"
        "IRONBAR_VOLUME_SET_DEFAULT_SINK=${setDefaultSinkScript}"
      ];
      ExecStart = ironbarStartScript;
      ExecStartPost = ironbarHealthScript;
      ExecReload = "${ironbarBin} reload";
      Restart = "on-failure";
      RestartSec = 1;
      KillMode = "mixed";
    };

    Install = {
      WantedBy = [ config.wayland.systemd.target ];
    };
  };

  systemd.user.services.ironbar-workspace-state = {
    Unit = {
      Description = "Ironbar workspace state updater";
      PartOf = [
        config.wayland.systemd.target
        "ironbar.service"
      ];
      Wants = [ "ironbar.service" ];
      After = [
        config.wayland.systemd.target
        "ironbar.service"
      ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
      X-Restart-Triggers = [
        "${config.xdg.configFile."ironbar/config.json".source}"
        "${config.xdg.configFile."ironbar/style.css".source}"
        workspaceStateScript
      ];
    };

    Service = {
      ExecStart = workspaceStateScript;
      Restart = "always";
      RestartSec = 1;
      KillMode = "mixed";
    };

    Install = {
      WantedBy = [ config.wayland.systemd.target ];
    };
  };
}
