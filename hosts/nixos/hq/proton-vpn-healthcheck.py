"""Check Proton's data path and rotate saved profiles after sustained failures."""

import argparse
from dataclasses import asdict, dataclass, replace
import errno
import ipaddress
import json
from pathlib import Path
import secrets
import socket
import struct
import subprocess
import time

from proton_vpn_profiles import ConfigError, ProfileStore


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
NETWORK_ERRORS = {
    errno.ENETDOWN, errno.ENETUNREACH, errno.EHOSTUNREACH, errno.ENODEV,
    errno.EADDRNOTAVAIL, errno.ECONNREFUSED, errno.ECONNRESET, errno.ETIMEDOUT,
}


@dataclass(frozen=True)
class State:
    invocation_id: str
    failures: int
    last_restart: float | None
    attempted_profiles: tuple[str, ...] = ()
    pending_profile: str | None = None


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


def bound_socket(interface, family, kind):
    connection = socket.socket(family, kind)
    try:
        connection.settimeout(CONNECT_TIMEOUT)
        connection.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, interface.encode() + b"\0")
    except OSError:
        connection.close()
        raise
    return connection


def connect_tcp(interface, target):
    family = socket.AF_INET6 if ":" in target[0] else socket.AF_INET
    with bound_socket(interface, family, socket.SOCK_STREAM) as connection:
        connection.connect(target)


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
    except DNSResponseError as error:
        print(f"probe failed: {description}: {error}", flush=True)
    except OSError as error:
        # A broken probe must fail visibly, without restarting the VPN. / 監視自体の権限不備では VPN を再起動しない。
        if not isinstance(error, TimeoutError) and error.errno not in NETWORK_ERRORS:
            raise
        print(f"probe failed: {description}: {error}", flush=True)
    return False


def probe(interface, connect=connect_tcp, resolve=query_configured_dns):
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


def queue_recovery(unit, state_file, state, profiles, previous, target, run):
    write_state(state_file, state)
    try:
        profiles.select(target)
        run(["systemctl", "restart", "--no-block", unit], check=True, timeout=10)
    except (ConfigError, OSError, subprocess.SubprocessError):
        profiles.select(previous)
        write_state(state_file, replace(state, pending_profile=None))
        raise
    print(f"recovery queued: {unit}; profile={previous.name} -> {target.name}", flush=True)


def check_once(interface, state_file, *, profiles, run=subprocess.run, check=probe, clock=time.monotonic):
    unit = f"wg-quick-{interface}.service"
    status, invocation_id = unit_status(unit, run)
    state = read_state(state_file)
    if status == "failed":
        raise RuntimeError(f"{unit} failed to start or stop; inspect its journal before changing profiles")
    if status != "active":
        print(f"skipping {unit}: {status}", flush=True)
        if status == "inactive" and state_file.exists():
            write_state(state_file, replace(state, failures=0, attempted_profiles=(), pending_profile=None))
        return

    candidates = profiles.load()
    current = profiles.selected(candidates)
    if state.pending_profile is not None and state.pending_profile != current.name:
        state = replace(state, failures=0, attempted_profiles=(), pending_profile=None)
    if state.pending_profile is not None and status == "active" and invocation_id == state.invocation_id:
        print(f"waiting for queued recovery: {unit}; profile={current.name}", flush=True)
        return

    reachable = check(interface)
    updated = observe(state, invocation_id, reachable)
    updated = replace(updated, pending_profile=None)
    target_name, updated = recovery_target(updated, current.name, tuple(p.name for p in candidates), clock())
    if target_name is None:
        write_state(state_file, updated)
        if not reachable or state.failures or state.pending_profile:
            action = "healthy" if reachable else "wait"
            if updated.failures == FAILURE_THRESHOLD:
                action = f"all {len(candidates)} profiles failed; cooldown={RESTART_COOLDOWN}s"
            print(f"{interface}: {action}; profile={current.name}; consecutive failures={updated.failures}", flush=True)
        return

    record_diagnostics(interface, run)
    if unit_status(unit, run) != (status, invocation_id) or profiles.selected(candidates).name != current.name:
        print(f"skipping recovery: {unit} changed during the check", flush=True)
        write_state(state_file, replace(state, failures=0, pending_profile=None))
        return

    if len(candidates) == 1:
        print("only one Proton profile is installed; restarting the same server", flush=True)
    target = next(profile for profile in candidates if profile.name == target_name)
    updated = replace(updated, failures=0, last_restart=clock(), pending_profile=target.name)
    queue_recovery(unit, state_file, updated, profiles, current, target, run)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--interface", required=True)
    parser.add_argument("--state-file", type=Path)
    parser.add_argument("--profiles-dir", type=Path, default=Path("/var/lib/proton-vpn"))
    parser.add_argument("--check-only", action="store_true", help="probe without state changes or recovery")
    arguments = parser.parse_args()
    if arguments.check_only:
        reachable = probe(arguments.interface)
        print(f"{arguments.interface}: {'reachable' if reachable else 'unreachable'}")
        return 0 if reachable else 1
    if arguments.state_file is None:
        parser.error("--state-file is required unless --check-only is used")
    check_once(arguments.interface, arguments.state_file, profiles=ProfileStore(arguments.profiles_dir))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
