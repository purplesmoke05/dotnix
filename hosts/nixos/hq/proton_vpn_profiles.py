"""Validate and select complete Proton WireGuard profiles.

The state directory contains the original legacy ``proton0.conf`` and any
additional profiles under ``profiles/``.  ``active.conf`` is the only
selector; runtime configuration is generated separately so a source profile
is never rewritten.
"""

from __future__ import annotations

import argparse
import base64
from dataclasses import dataclass, field
import ipaddress
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
from typing import Callable, Sequence


DEFAULT_STATE_DIR = Path("/var/lib/proton-vpn")
DEFAULT_RUNTIME_CONFIG = Path("/run/proton-vpn/proton0.conf")
ACTIVE_CONFIG_NAME = "active.conf"
PRIMARY_CONFIG_NAME = "proton0.conf"
PROFILE_DIRECTORY_NAME = "profiles"


class ConfigError(ValueError):
    """A safe, user-facing configuration error."""


class SelectionError(ConfigError):
    """The persistent profile selector is absent or invalid."""


@dataclass(frozen=True)
class Profile:
    name: str
    source: Path
    endpoint_host: str
    endpoint_port: int
    text: str = field(repr=False)


_INTERFACE_KEYS = {
    "privatekey": "PrivateKey",
    "address": "Address",
    "dns": "DNS",
    "mtu": "MTU",
    "listenport": "ListenPort",
    "table": "Table",
}
_PEER_KEYS = {
    "publickey": "PublicKey",
    "presharedkey": "PresharedKey",
    "allowedips": "AllowedIPs",
    "endpoint": "Endpoint",
    "persistentkeepalive": "PersistentKeepalive",
}
_REJECTED_INTERFACE_KEYS = {
    "saveconfig",
    "preup",
    "postup",
    "predown",
    "postdown",
    "customtable",
    "fwmark",
}
_DNS_LINE = re.compile(r"^[ \t]*DNS[ \t]*=", re.IGNORECASE)


def _invalid(profile_name: str, reason: str) -> ConfigError:
    # Use fixed field labels so errors omit input lines, key material, and parser exceptions. / エラーには入力行・鍵素材・パーサー例外を含めず、固定の項目名だけを示す。
    return ConfigError(f"invalid WireGuard profile {profile_name}: {reason}")


def _secure_file(path: Path, profile_name: str) -> None:
    try:
        metadata = os.lstat(path)
    except (OSError, ValueError):
        raise _invalid(profile_name, "profile file is unavailable") from None
    if not stat.S_ISREG(metadata.st_mode):
        raise _invalid(profile_name, "profile file is not regular") from None
    if metadata.st_uid != os.geteuid():
        raise _invalid(profile_name, "profile ownership is unsafe") from None
    if stat.S_IMODE(metadata.st_mode) & 0o077:
        raise _invalid(profile_name, "profile permissions are unsafe") from None


def _read_profile(path: Path, name: str) -> str:
    _secure_file(path, name)
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        raise _invalid(name, "profile text is unreadable") from None


def _split_values(value: str) -> list[str]:
    return [item for item in re.split(r"[\s,]+", value.strip()) if item]


def _decode_key(value: str, profile_name: str, field_name: str) -> None:
    try:
        decoded = base64.b64decode(value, validate=True)
    except (ValueError, TypeError):
        raise _invalid(profile_name, f"invalid {field_name}") from None
    if len(decoded) != 32:
        raise _invalid(profile_name, f"invalid {field_name}") from None


def _integer(value: str, profile_name: str, field_name: str, *, minimum: int) -> int:
    if not re.fullmatch(r"[0-9]+", value):
        raise _invalid(profile_name, f"invalid {field_name}") from None
    try:
        number = int(value)
    except ValueError:
        raise _invalid(profile_name, f"invalid {field_name}") from None
    if not minimum <= number <= 65535:
        raise _invalid(profile_name, f"invalid {field_name}") from None
    return number


def _parse_endpoint(value: str, profile_name: str) -> tuple[str, int]:
    if value.startswith("["):
        closing = value.find("]")
        if closing < 0 or closing + 1 >= len(value) or value[closing + 1] != ":":
            raise _invalid(profile_name, "invalid Endpoint") from None
        host = value[1:closing]
        port_text = value[closing + 2 :]
        if "%" in host:
            raise _invalid(profile_name, "invalid Endpoint") from None
        try:
            address = ipaddress.IPv6Address(host)
        except ValueError:
            raise _invalid(profile_name, "invalid Endpoint") from None
    else:
        if value.count(":") != 1:
            raise _invalid(profile_name, "invalid Endpoint") from None
        host, port_text = value.rsplit(":", 1)
        try:
            address = ipaddress.IPv4Address(host)
        except ValueError:
            raise _invalid(profile_name, "invalid Endpoint") from None
    port = _integer(port_text, profile_name, "Endpoint", minimum=1)
    return str(address), port


def _parse_config(text: str, profile_name: str) -> tuple[str, int]:
    sections: dict[str, dict[str, str]] = {}
    current: str | None = None
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            if section not in ("Interface", "Peer"):
                raise _invalid(profile_name, "unsupported section") from None
            if section in sections:
                raise _invalid(profile_name, "duplicate section") from None
            sections[section] = {}
            current = section
            continue
        if current is None or "=" not in line:
            raise _invalid(profile_name, "malformed setting") from None
        raw_key, raw_value = line.split("=", 1)
        key = raw_key.strip().lower()
        value = raw_value.strip()
        if not key or not value:
            raise _invalid(profile_name, "malformed setting") from None
        allowed = _INTERFACE_KEYS if current == "Interface" else _PEER_KEYS
        if key in _REJECTED_INTERFACE_KEYS:
            raise _invalid(profile_name, "unsupported routing or shell setting") from None
        if key not in allowed:
            raise _invalid(profile_name, "unsupported setting") from None
        if key in sections[current]:
            raise _invalid(profile_name, "duplicate setting") from None
        sections[current][key] = value

    if set(sections) != {"Interface", "Peer"}:
        raise _invalid(profile_name, "exactly one Interface and Peer are required") from None

    interface = sections["Interface"]
    peer = sections["Peer"]
    for key in ("privatekey", "address"):
        if key not in interface:
            raise _invalid(profile_name, f"missing {_INTERFACE_KEYS[key]}") from None
    for key in ("publickey", "allowedips", "endpoint"):
        if key not in peer:
            raise _invalid(profile_name, f"missing {_PEER_KEYS[key]}") from None

    _decode_key(interface["privatekey"], profile_name, "PrivateKey")
    _decode_key(peer["publickey"], profile_name, "PublicKey")
    if "presharedkey" in peer:
        _decode_key(peer["presharedkey"], profile_name, "PresharedKey")

    addresses = _split_values(interface["address"])
    versions: set[int] = set()
    for address_text in addresses:
        try:
            versions.add(ipaddress.ip_interface(address_text).version)
        except ValueError:
            raise _invalid(profile_name, "invalid Address") from None
    if not {4, 6}.issubset(versions):
        raise _invalid(profile_name, "Address must include IPv4 and IPv6") from None

    if "dns" in interface:
        for dns_text in _split_values(interface["dns"]):
            try:
                ipaddress.ip_address(dns_text)
            except ValueError:
                raise _invalid(profile_name, "invalid DNS") from None
    if "mtu" in interface:
        _integer(interface["mtu"], profile_name, "MTU", minimum=1)
    if "listenport" in interface:
        _integer(interface["listenport"], profile_name, "ListenPort", minimum=0)
    if "table" in interface and interface["table"].lower() != "auto":
        raise _invalid(profile_name, "Table must be auto") from None

    allowed_ips = _split_values(peer["allowedips"])
    allowed_versions: set[int] = set()
    for network_text in allowed_ips:
        try:
            network = ipaddress.ip_network(network_text, strict=False)
        except ValueError:
            raise _invalid(profile_name, "invalid AllowedIPs") from None
        if network.prefixlen == 0:
            allowed_versions.add(network.version)
    if not {4, 6}.issubset(allowed_versions):
        raise _invalid(profile_name, "AllowedIPs must include IPv4 and IPv6 defaults") from None

    endpoint_host, endpoint_port = _parse_endpoint(peer["endpoint"], profile_name)
    if "persistentkeepalive" in peer:
        _integer(
            peer["persistentkeepalive"],
            profile_name,
            "PersistentKeepalive",
            minimum=0,
        )
    return endpoint_host, endpoint_port


def _endpoint_identity(profile: Profile) -> tuple[int, bytes, int]:
    address = ipaddress.ip_address(profile.endpoint_host)
    return address.version, address.packed, profile.endpoint_port


def read_profile(path: Path, name: str) -> Profile:
    """Read and validate one protected profile without changing filesystem state."""

    source = Path(path)
    text = _read_profile(source, name)
    endpoint_host, endpoint_port = _parse_config(text, name)
    return Profile(name, source, endpoint_host, endpoint_port, text)


class ProfileStore:
    """Read profile candidates and atomically manage the active selector."""

    def __init__(self, root: Path):
        self.root = Path(root)

    @property
    def active_path(self) -> Path:
        return self.root / ACTIVE_CONFIG_NAME

    def _source_paths(self) -> list[Path]:
        primary = self.root / PRIMARY_CONFIG_NAME
        profile_dir = self.root / PROFILE_DIRECTORY_NAME
        if profile_dir.exists() and not profile_dir.is_dir():
            raise _invalid("profiles", "profile directory is invalid") from None
        extras = []
        if profile_dir.is_dir():
            extras = sorted(profile_dir.glob("*.conf"), key=lambda path: path.stem)
        return [primary, *extras]

    def load(self) -> tuple[Profile, ...]:
        paths = self._source_paths()
        profiles: list[Profile] = []
        names: set[str] = set()
        endpoint_ids: set[tuple[int, bytes, int]] = set()
        for index, path in enumerate(paths):
            name = "primary" if index == 0 else path.stem
            if name in names:
                raise _invalid(name, "duplicate profile name") from None
            names.add(name)
            profile = read_profile(path, name)
            endpoint_id = _endpoint_identity(profile)
            if endpoint_id in endpoint_ids:
                raise _invalid(name, "duplicate Endpoint") from None
            endpoint_ids.add(endpoint_id)
            profiles.append(profile)
        if not profiles:
            raise _invalid("primary", "profile file is unavailable") from None
        return tuple(profiles)

    def selected(self, profiles: Sequence[Profile]) -> Profile:
        active = self.active_path
        if not active.is_symlink():
            if active.exists():
                raise SelectionError("active.conf must be a symlink")
            raise SelectionError("active.conf is missing")
        try:
            target = active.resolve(strict=False)
        except (OSError, RuntimeError, ValueError):
            raise SelectionError("active.conf target is invalid") from None
        if not target.exists():
            raise SelectionError("active.conf target is dangling")
        for profile in profiles:
            try:
                source = Path(profile.source).resolve(strict=False)
            except (OSError, RuntimeError, ValueError):
                raise SelectionError("declared profile path is invalid") from None
            if source == target:
                return profile
        raise SelectionError("active.conf target is not a declared profile")

    def _declared_source(self, source: Path) -> bool:
        try:
            source_resolved = source.resolve(strict=False)
        except (OSError, RuntimeError, ValueError):
            raise SelectionError("profile path is invalid") from None
        for candidate in self._source_paths():
            try:
                if candidate.resolve(strict=False) == source_resolved:
                    return True
            except (OSError, RuntimeError, ValueError):
                raise SelectionError("declared profile path is invalid") from None
        return False

    def select(self, profile: Profile) -> Profile:
        source = Path(profile.source)
        if not self._declared_source(source):
            raise SelectionError("profile is not declared by this store")
        _secure_file(source, profile.name)
        self.root.mkdir(parents=True, exist_ok=True)
        temporary: Path | None = None
        try:
            descriptor, temporary_name = tempfile.mkstemp(
                prefix=".active.", dir=self.root
            )
            os.close(descriptor)
            temporary = Path(temporary_name)
            temporary.unlink()
            relative_source = os.path.relpath(source, self.root)
            os.symlink(relative_source, temporary)
            os.replace(temporary, self.active_path)
            temporary = None
        finally:
            if temporary is not None:
                try:
                    temporary.unlink()
                except FileNotFoundError:
                    pass
        return profile

    def initialize(self, profiles: Sequence[Profile]) -> Profile:
        active = self.active_path
        if not active.exists() and not active.is_symlink():
            if not profiles or profiles[0].name != "primary":
                raise SelectionError("primary profile is unavailable")
            return self.select(profiles[0])
        return self.selected(profiles)


def _strip_dns(text: str) -> str:
    return "".join(line for line in text.splitlines(keepends=True) if not _DNS_LINE.match(line))


def _resolved(path: Path) -> Path:
    try:
        return path.resolve(strict=False)
    except (OSError, RuntimeError, ValueError):
        raise ConfigError("profile path cannot be resolved") from None


def _same_path(left: Path, right: Path) -> bool:
    return _resolved(left) == _resolved(right)


def write_runtime_config(profile: Profile, runtime_config: Path, candidates: Sequence[Profile] = ()) -> Path:
    """Atomically write one selected profile with DNS directives removed."""

    runtime = Path(runtime_config)
    for candidate in candidates:
        if _same_path(runtime, Path(candidate.source)):
            raise ConfigError("runtime config must not replace a source profile")
    if not candidates and _same_path(runtime, Path(profile.source)):
        raise ConfigError("runtime config must not replace a source profile")
    parent = runtime.parent
    try:
        parent.mkdir(parents=True, exist_ok=True)
        os.chmod(parent, 0o700)
    except OSError:
        raise ConfigError("runtime directory is unavailable") from None

    temporary: Path | None = None
    descriptor = -1
    try:
        descriptor, temporary_name = tempfile.mkstemp(prefix=f".{runtime.name}.", dir=parent)
        temporary = Path(temporary_name)
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as output:
            descriptor = -1
            output.write(_strip_dns(profile.text))
            output.flush()
            os.fsync(output.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, runtime)
        temporary = None
    except (OSError, UnicodeError):
        raise ConfigError("could not atomically write runtime config") from None
    finally:
        if descriptor >= 0:
            os.close(descriptor)
        if temporary is not None:
            try:
                temporary.unlink()
            except FileNotFoundError:
                pass
    return runtime


def prepare(store: ProfileStore, runtime_config: Path) -> Profile:
    profiles = store.load()
    selected = store.initialize(profiles)
    write_runtime_config(selected, runtime_config, profiles)
    return selected


def _load_runtime_profile(runtime_config: Path) -> Profile:
    return read_profile(Path(runtime_config), "runtime")


def apply_endpoint_sets(
    runtime_config: Path,
    *,
    run: Callable[..., object] = subprocess.run,
) -> None:
    """Update both killswitch endpoint sets in one nft transaction."""

    profile = _load_runtime_profile(Path(runtime_config))
    address = ipaddress.ip_address(profile.endpoint_host)
    family = "proton_vpn4_endpoints" if address.version == 4 else "proton_vpn6_endpoints"
    payload = "\n".join(
        (
            "flush set inet proton-killswitch proton_vpn4_endpoints",
            "flush set inet proton-killswitch proton_vpn6_endpoints",
            f"add element inet proton-killswitch {family} {{ {address} . {profile.endpoint_port} }}",
        )
    ) + "\n"
    run(["nft", "-f", "-"], input=payload, text=True, check=True)


def _endpoint_text(profile: Profile) -> str:
    if ":" in profile.endpoint_host:
        return f"[{profile.endpoint_host}]:{profile.endpoint_port}"
    return f"{profile.endpoint_host}:{profile.endpoint_port}"


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-dir", type=Path, default=DEFAULT_STATE_DIR)
    parser.add_argument("--runtime-config", type=Path, default=DEFAULT_RUNTIME_CONFIG)
    commands = parser.add_subparsers(dest="command", required=True)
    validate = commands.add_parser("validate", help="validate candidate profiles")
    validate.add_argument("--require-alternatives", action="store_true")
    commands.add_parser("prepare", help="select and write the runtime profile")
    commands.add_parser("endpoints", help="load the runtime endpoint into nftables")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    try:
        if arguments.command == "validate":
            store = ProfileStore(arguments.state_dir)
            profiles = store.load()
            active = arguments.state_dir / ACTIVE_CONFIG_NAME
            if active.exists() or active.is_symlink():
                store.selected(profiles)
            if arguments.require_alternatives and len(profiles) < 2:
                raise ConfigError("at least two distinct endpoints are required")
            for profile in profiles:
                print(f"{profile.name} {_endpoint_text(profile)}")
            print(f"count {len(profiles)}")
            return 0
        if arguments.command == "prepare":
            prepare(ProfileStore(arguments.state_dir), arguments.runtime_config)
            return 0
        if arguments.command == "endpoints":
            apply_endpoint_sets(arguments.runtime_config)
            return 0
    except ConfigError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
