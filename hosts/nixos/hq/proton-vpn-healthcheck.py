"""Check Proton's data path, rotate saved profiles after sustained failures, and fail back to the primary profile."""

import argparse
from dataclasses import asdict, dataclass, replace
import errno
import ipaddress
import json
from pathlib import Path
import secrets
import socket
import ssl
import struct
import subprocess
import sys
import time

from proton_vpn_profiles import ConfigError, ProfileStore, probe_tunnel


PROBE_TARGETS = (
    (("1.1.1.1", 443), ("8.8.8.8", 443)),
    (("2606:4700:4700::1111", 443), ("2001:4860:4860::8888", 443)),
)
DNS_SERVER = ("10.2.0.1", 53)
DNS_NAME = "example.com"
DNS_RECORD_TYPES = (1, 28)
DNS_HEADER_SIZE = 12
CONNECT_TIMEOUT = 5
FAILURE_THRESHOLD = 3
RESTART_COOLDOWN = 300
FAILBACK_AFTER = 600
FAILBACK_AFTER_MAX = 7200
FAILBACK_STABLE = 3600
PRIMARY_PROBE_GAP = 180
PROBE_NAMESPACE = "proton-probe"
PROBE_INTERFACE = "pvpn-probe0"
PROBE_TIMEOUT = 60
# A fresh Proton session closes TLS for its first seconds, so one failure right after setup proves nothing. / Proton は新しい接続の最初の数秒は TLS を切るため、作った直後の 1 回の失敗では判定しない。
PROBE_SETTLE = 30
PROBE_RETRY_GAP = 2
NETWORK_ERRORS = {
    errno.ENETDOWN, errno.ENETUNREACH, errno.EHOSTUNREACH, errno.ENODEV,
    errno.EADDRNOTAVAIL, errno.ECONNREFUSED, errno.ECONNRESET, errno.EPIPE, errno.ETIMEDOUT,
}


@dataclass(frozen=True)
class State:
    invocation_id: str
    failures: int
    last_restart: float | None
    attempted_profiles: tuple[str, ...] = ()
    pending_profile: str | None = None
    failback_after: float = FAILBACK_AFTER
    failback_from: str | None = None
    last_failback: float | None = None
    primary_healthy_since: float | None = None
    primary_checked_at: float | None = None


def observe(state, invocation_id, reachable):
    if state.invocation_id != invocation_id and state.pending_profile is None:
        state = replace(state, failures=0, attempted_profiles=())
    state = replace(state, invocation_id=invocation_id)
    if reachable:
        return replace(state, failures=0, attempted_profiles=(), pending_profile=None)
    return replace(state, failures=min(state.failures + 1, FAILURE_THRESHOLD))


def recovery_target(state, current, names, now):
    if state.failures < FAILURE_THRESHOLD:
        return None, state

    attempted = tuple(dict.fromkeys((*state.attempted_profiles, current)))
    state = replace(state, attempted_profiles=attempted)
    index = names.index(current)
    ordered = names[index + 1:] + names[:index + 1]
    untried = [name for name in ordered if name not in attempted]
    if untried:
        return untried[0], state
    if state.last_restart is not None and now - state.last_restart < RESTART_COOLDOWN:
        return None, state
    return ordered[0], replace(state, attempted_profiles=(current,) if len(names) > 1 else ())


def recently_failed_back(state, now):
    return state.last_failback is not None and now - state.last_failback < FAILBACK_STABLE


def leave_primary(state, current, target, names, now):
    primary = names[0]
    if current != primary or target == primary:
        return target, state
    # A failed failback returns to the backup that was last healthy. / primary に戻して失敗したら、直前まで正常だったバックアップへ戻す。
    if state.failback_from in names[1:]:
        target = state.failback_from
    after = min(state.failback_after * 2, FAILBACK_AFTER_MAX) if recently_failed_back(state, now) else FAILBACK_AFTER
    return target, replace(state, failback_after=after, failback_from=None,
                           primary_healthy_since=None, primary_checked_at=None)


def failback_target(state, current, names, now, primary_reachable):
    primary = names[0]
    if current == primary:
        keep = state.failback_from if recently_failed_back(state, now) else None
        return None, replace(state, failback_from=keep, primary_healthy_since=None, primary_checked_at=None)
    if not primary_reachable:
        return None, replace(state, primary_healthy_since=None, primary_checked_at=now)
    resumed = state.primary_checked_at is None or now - state.primary_checked_at > PRIMARY_PROBE_GAP
    since = now if resumed or state.primary_healthy_since is None else state.primary_healthy_since
    if now - since < state.failback_after:
        return None, replace(state, primary_healthy_since=since, primary_checked_at=now)
    return primary, replace(state, failback_from=current, last_failback=now,
                            primary_healthy_since=None, primary_checked_at=None)


def primary_probe_failing(state, now):
    """Whether the previous primary probe failed recently, so a new failure continues a known streak."""
    return (state.primary_healthy_since is None and state.primary_checked_at is not None
            and now - state.primary_checked_at <= PRIMARY_PROBE_GAP)


def run_quietly(run, command):
    try:
        run(command, check=False, capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        pass


def remove_probe_tunnel(run):
    run_quietly(run, ["ip", "netns", "delete", PROBE_NAMESPACE])
    run_quietly(run, ["ip", "link", "delete", PROBE_INTERFACE])


def allow_probe_endpoint(primary, run):
    # The endpoint sets only gain the primary when the tunnel restarts, so add it here too. / 許可リストに primary が入るのはトンネルの起動時なので、ここでも足しておく。
    address = ipaddress.ip_address(primary.endpoint_host)
    family = "proton_vpn4_endpoints" if address.version == 4 else "proton_vpn6_endpoints"
    run_quietly(run, ["nft", "add", "element", "inet", "proton-killswitch", family,
                      f"{{ {address} . {primary.endpoint_port} }}"])


def primary_path_reachable(primary, interface, run=subprocess.run, clock=time.monotonic, sleep=time.sleep):
    """Probe the primary server directly through a temporary tunnel in its own network namespace."""
    try:
        fwmark = run(["wg", "show", interface, "fwmark"], check=True, capture_output=True, text=True,
                     timeout=5).stdout.strip()
        tunnel = probe_tunnel(primary, fwmark)
    except (ConfigError, OSError, subprocess.SubprocessError):
        # Without the main tunnel's fwmark the probe would ride inside the active tunnel. / 本線の fwmark がないと、確認用の通信が本線のトンネルの中を通ってしまう。
        return False, f"probe needs the fwmark of {interface}"
    namespace = ["ip", "-n", PROBE_NAMESPACE]
    setup = [
        (["ip", "netns", "add", PROBE_NAMESPACE], None),
        (["ip", "link", "add", PROBE_INTERFACE, "type", "wireguard"], None),
        (["wg", "setconf", PROBE_INTERFACE, "/dev/stdin"], tunnel.setconf),
        (["ip", "link", "set", PROBE_INTERFACE, "netns", PROBE_NAMESPACE], None),
        *[([*namespace, "address", "add", address, "dev", PROBE_INTERFACE], None) for address in tunnel.addresses],
        ([*namespace, "link", "set", "lo", "up"], None),
        ([*namespace, "link", "set", PROBE_INTERFACE, "up"], None),
        ([*namespace, "-4", "route", "add", "default", "dev", PROBE_INTERFACE], None),
        ([*namespace, "-6", "route", "add", "default", "dev", PROBE_INTERFACE], None),
    ]
    remove_probe_tunnel(run)
    allow_probe_endpoint(primary, run)
    try:
        for command, stdin in setup:
            try:
                run(command, input=stdin, check=True, capture_output=True, text=True, timeout=10)
            except (OSError, subprocess.SubprocessError):
                # wg can quote the rejected line, which may hold the private key. / wg は受け付けなかった行を表示することがあり、秘密鍵を含みうる。
                return False, f"probe setup failed: {' '.join(command[:3])}"
        deadline = clock() + PROBE_SETTLE
        attempts = 0
        while True:
            attempts += 1
            try:
                result = run(
                    ["ip", "netns", "exec", PROBE_NAMESPACE, sys.executable, str(Path(__file__).resolve()),
                     "--check-only", "--interface", PROBE_INTERFACE, "--dns-server", DNS_SERVER[0]],
                    check=False, capture_output=True, text=True, timeout=PROBE_TIMEOUT,
                )
            except subprocess.TimeoutExpired:
                return False, "probe timed out"
            lines = (result.stdout + result.stderr).strip().splitlines()
            if result.returncode == 0:
                return True, lines[-1] if lines else "probe passed"
            if clock() + PROBE_RETRY_GAP >= deadline:
                # The summary line does not say which target failed, so report the last reason. / 要約の行ではどの宛先で失敗したか分からないため、最後の理由を返す。
                reasons = [line for line in lines if line.startswith("probe failed: ")] or lines
                reason = reasons[-1] if reasons else f"probe exited with {result.returncode}"
                return False, f"{reason} ({attempts} attempts)"
            sleep(PROBE_RETRY_GAP)
    finally:
        remove_probe_tunnel(run)


def bound_socket(interface, family, kind):
    connection = socket.socket(family, kind)
    try:
        connection.settimeout(CONNECT_TIMEOUT)
        connection.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, interface.encode() + b"\0")
    except OSError:
        connection.close()
        raise
    return connection


def connect_tls(interface, target):
    family = socket.AF_INET6 if ":" in target[0] else socket.AF_INET
    # Proton can answer TCP on the VPN server, so only a TLS reply proves the path beyond it. / Proton は VPN サーバーで TCP に応答することがあるため、その先の疎通は TLS の応答で確かめる。
    # Certificates stay unverified so a clock or CA problem is not mistaken for an outage. / 時刻や CA の不備を障害と誤認しないよう、証明書は検証しない。
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    with bound_socket(interface, family, socket.SOCK_STREAM) as connection:
        connection.connect(target)
        with context.wrap_socket(connection):
            pass


class DNSResponseError(Exception):
    pass


def query_dns(interface, record_type, server=DNS_SERVER):
    identifier = secrets.randbelow(65536)
    question = b"".join(bytes([len(label)]) + label.encode() for label in DNS_NAME.split("."))
    request = struct.pack("!6H", identifier, 0x0100, 1, 0, 0, 0)
    request += question + b"\0" + struct.pack("!2H", record_type, 1)
    address = ipaddress.ip_address(server[0])
    family = socket.AF_INET6 if address.version == 6 else socket.AF_INET
    device = "lo" if address.is_loopback else interface
    with bound_socket(device, family, socket.SOCK_DGRAM) as connection:
        connection.connect(server)
        connection.send(request)
        response = connection.recv(4096)
    if len(response) < DNS_HEADER_SIZE:
        raise DNSResponseError("short DNS response")
    response_id, flags, questions, answers, _, _ = struct.unpack("!6H", response[:DNS_HEADER_SIZE])
    if response_id != identifier or not flags & 0x8000 or flags & 0x020F or questions != 1 or answers == 0:
        raise DNSResponseError("DNS response has no successful, complete answer")
    if response[DNS_HEADER_SIZE:len(request)] != request[DNS_HEADER_SIZE:] or len(response) <= len(request):
        raise DNSResponseError("DNS response does not contain the requested question and answer")


def query_configured_dns(interface, record_type):
    servers = [line.split()[1] for line in Path("/etc/resolv.conf").read_text().splitlines()
               if line.split()[:1] == ["nameserver"]]
    if not servers:
        raise ValueError("no nameserver is configured in /etc/resolv.conf")
    for server in servers:
        if network_check(f"DNS {server} ({record_type})", lambda: query_dns(interface, record_type, (server, 53))):
            return
    raise DNSResponseError("all configured DNS servers failed")


def network_check(description, operation):
    try:
        operation()
        return True
    except (DNSResponseError, ssl.SSLError) as error:
        print(f"probe failed: {description}: {error}", flush=True)
    except OSError as error:
        # A broken probe must fail visibly, without restarting the VPN. / 監視自体の権限不備では VPN を再起動しない。
        if not isinstance(error, TimeoutError) and error.errno not in NETWORK_ERRORS:
            raise
        print(f"probe failed: {description}: {error}", flush=True)
    return False


def probe(interface, connect=connect_tls, resolve=query_configured_dns):
    for targets in PROBE_TARGETS:
        if not any(network_check(f"{interface} -> {target[0]}:{target[1]}",
                                 lambda target=target: connect(interface, target)) for target in targets):
            return False
    return all(network_check(f"configured DNS ({record_type})",
                             lambda record_type=record_type: resolve(interface, record_type))
               for record_type in DNS_RECORD_TYPES)


def read_state(path):
    if not path.exists():
        return State("", 0, None)
    data = json.loads(path.read_text())
    data["attempted_profiles"] = tuple(data.get("attempted_profiles", ()))
    return State(**data)


def write_state(path, state):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(asdict(state)) + "\n")
    temporary.replace(path)


def unit_status(unit, run):
    result = run(
        ["systemctl", "show", unit, "--property=ActiveState,InvocationID"],
        check=True, capture_output=True, text=True, timeout=10,
    )
    properties = dict(line.split("=", 1) for line in result.stdout.splitlines())
    return properties["ActiveState"], properties["InvocationID"]


def record_diagnostics(interface, run):
    commands = [
        ["wg", "show", interface, field]
        for field in ("latest-handshakes", "transfer", "endpoints", "persistent-keepalive", "fwmark")
    ]
    commands += [
        ["ip", "-4", "rule", "show"],
        ["ip", "-4", "route", "show", "table", "all"],
        ["nft", "list", "table", "inet", "proton-killswitch"],
    ]
    for command in commands:
        try:
            result = run(command, check=False, capture_output=True, text=True, timeout=5)
        except subprocess.TimeoutExpired:
            print(f"diagnostic timed out: {' '.join(command)}", flush=True)
            continue
        print(f"diagnostic: {' '.join(command)} (exit {result.returncode})", flush=True)
        print(result.stdout + result.stderr, end="", flush=True)


def queue_recovery(unit, state_file, state, profiles, previous, target, run, action="recovery"):
    write_state(state_file, state)
    try:
        profiles.select(target)
        run(["systemctl", "restart", "--no-block", unit], check=True, timeout=10)
    except (ConfigError, OSError, subprocess.SubprocessError):
        profiles.select(previous)
        write_state(state_file, replace(state, pending_profile=None))
        raise
    print(f"{action} queued: {unit}; profile={previous.name} -> {target.name}", flush=True)


def check_once(interface, state_file, *, profiles, run=subprocess.run, check=probe, clock=time.monotonic,
               primary_check=None):
    unit = f"wg-quick-{interface}.service"
    status, invocation_id = unit_status(unit, run)
    state = read_state(state_file)
    if status == "failed":
        raise RuntimeError(f"{unit} failed to start or stop; inspect its journal before changing profiles")
    if status != "active":
        print(f"skipping {unit}: {status}", flush=True)
        if status == "inactive" and state_file.exists():
            write_state(state_file, replace(state, failures=0, attempted_profiles=(), pending_profile=None,
                                            failback_from=None, primary_healthy_since=None, primary_checked_at=None))
        return

    candidates = profiles.load()
    current = profiles.selected(candidates)
    if state.pending_profile is not None and state.pending_profile != current.name:
        state = replace(state, failures=0, attempted_profiles=(), pending_profile=None)
    if state.pending_profile is not None and status == "active" and invocation_id == state.invocation_id:
        print(f"waiting for queued recovery: {unit}; profile={current.name}", flush=True)
        return

    reachable = check(interface)
    now = clock()
    names = tuple(profile.name for profile in candidates)
    updated = observe(state, invocation_id, reachable)
    updated = replace(updated, pending_profile=None)
    target_name, updated = recovery_target(updated, current.name, names, now)
    action = "recovery"
    if target_name is not None:
        target_name, updated = leave_primary(updated, current.name, target_name, names, now)
    elif not reachable:
        updated = replace(updated, primary_healthy_since=None)
    else:
        action = "failback"
        primary_reachable, detail = None, ""
        if current.name != names[0]:
            primary_check = primary_check or (lambda profile: primary_path_reachable(profile, interface, run))
            primary_reachable, detail = primary_check(candidates[0])
        target_name, updated = failback_target(updated, current.name, names, now, primary_reachable)
        if primary_reachable and state.primary_healthy_since is None and updated.primary_healthy_since is not None:
            print(f"{interface}: {names[0]} is reachable through the probe tunnel; "
                  f"failing back after {round(updated.failback_after)}s of continuous health", flush=True)
        elif primary_reachable is False and not primary_probe_failing(state, now):
            # Log when a failure streak starts, so a probe that never passes is visible. / 失敗が始まったら記録し、一度も通らない確認に気づけるようにする。
            print(f"{interface}: {names[0]} probe failed; staying on {current.name}: {detail}", flush=True)
    if target_name is None:
        write_state(state_file, updated)
        if not reachable or state.failures or state.pending_profile:
            status_text = "healthy" if reachable else "wait"
            if updated.failures == FAILURE_THRESHOLD:
                status_text = f"all {len(candidates)} profiles failed; cooldown={RESTART_COOLDOWN}s"
            print(f"{interface}: {status_text}; profile={current.name}; consecutive failures={updated.failures}",
                  flush=True)
        return

    if action == "recovery":
        record_diagnostics(interface, run)
    if unit_status(unit, run) != (status, invocation_id) or profiles.selected(candidates).name != current.name:
        print(f"skipping {action}: {unit} changed during the check", flush=True)
        write_state(state_file, replace(state, failures=0, pending_profile=None))
        return

    if len(candidates) == 1:
        print("only one Proton profile is installed; restarting the same server", flush=True)
    target = next(profile for profile in candidates if profile.name == target_name)
    updated = replace(updated, failures=0, last_restart=now, pending_profile=target.name)
    queue_recovery(unit, state_file, updated, profiles, current, target, run, action)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--interface", required=True)
    parser.add_argument("--state-file", type=Path)
    parser.add_argument("--profiles-dir", type=Path, default=Path("/var/lib/proton-vpn"))
    parser.add_argument("--check-only", action="store_true", help="probe without state changes or recovery")
    parser.add_argument("--dns-server", type=ipaddress.ip_address,
                        help="with --check-only, query this server instead of /etc/resolv.conf")
    arguments = parser.parse_args()
    if arguments.check_only:
        resolve = query_configured_dns
        if arguments.dns_server is not None:
            server = (str(arguments.dns_server), 53)

            def resolve(interface, record_type):
                query_dns(interface, record_type, server)

        reachable = probe(arguments.interface, resolve=resolve)
        print(f"{arguments.interface}: {'reachable' if reachable else 'unreachable'}")
        return 0 if reachable else 1
    if arguments.state_file is None:
        parser.error("--state-file is required unless --check-only is used")
    check_once(arguments.interface, arguments.state_file, profiles=ProfileStore(arguments.profiles_dir))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
