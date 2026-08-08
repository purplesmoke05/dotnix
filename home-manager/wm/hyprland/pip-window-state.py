#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import math
import os
import signal
import socket
import subprocess
import sys
import tempfile
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


STATE_VERSION = 1
PIP_TITLES = {"Picture in picture", "ピクチャー イン ピクチャー"}
RELEVANT_WINDOW_EVENTS = {
    "closewindow",
    "openwindow",
    "windowtitle",
    "windowtitlev2",
}
RELEVANT_MONITOR_EVENTS = {
    "configreloaded",
    "monitoradded",
    "monitoraddedv2",
    "monitorremoved",
}


class PipStateError(RuntimeError):
    pass


def log(message: str) -> None:
    print(f"pip-window-state: {message}", file=sys.stderr, flush=True)


def env_float(name: str, default: float) -> float:
    raw = os.environ.get(name, str(default))
    try:
        value = float(raw)
    except ValueError as error:
        raise PipStateError(f"{name} must be a number, got {raw!r}") from error
    if not math.isfinite(value) or value <= 0:
        raise PipStateError(f"{name} must be greater than zero, got {raw!r}")
    return value


@dataclass(frozen=True)
class Geometry:
    monitor: str
    x: int
    y: int
    width: int
    height: int

    def to_json(self) -> dict[str, int | str]:
        return {"version": STATE_VERSION, **asdict(self)}


@dataclass(frozen=True)
class Monitor:
    id: int
    name: str
    x: int
    y: int
    width: int
    height: int

    @classmethod
    def from_hyprland(cls, raw: dict[str, Any]) -> Monitor:
        scale = float(raw["scale"])
        if not math.isfinite(scale) or scale <= 0:
            raise PipStateError(
                f"monitor {raw.get('name', '<unknown>')} has invalid scale {scale}"
            )

        transform = int(raw["transform"])
        rotated = transform % 2 == 1
        physical_width = int(raw["height"] if rotated else raw["width"])
        physical_height = int(raw["width"] if rotated else raw["height"])

        return cls(
            id=int(raw["id"]),
            name=str(raw["name"]),
            x=int(raw["x"]),
            y=int(raw["y"]),
            width=math.floor(physical_width / scale),
            height=math.floor(physical_height / scale),
        )


class StateStore:
    def __init__(self, path: Path) -> None:
        self.path = path

    def exists(self) -> bool:
        return self.path.exists()

    def load(self) -> Geometry:
        try:
            with self.path.open(encoding="utf-8") as handle:
                raw = json.load(handle)
        except OSError as error:
            raise PipStateError(
                f"cannot read state file {self.path}: {error}"
            ) from error
        except json.JSONDecodeError as error:
            raise PipStateError(
                f"invalid JSON in state file {self.path}: {error}"
            ) from error

        if not isinstance(raw, dict):
            raise PipStateError(f"state file {self.path} must contain a JSON object")
        if raw.get("version") != STATE_VERSION:
            raise PipStateError(
                f"state file {self.path} has unsupported version {raw.get('version')!r}"
            )

        monitor = raw.get("monitor")
        if not isinstance(monitor, str) or not monitor:
            raise PipStateError(f"state file {self.path} has an invalid monitor")

        values: dict[str, int] = {}
        for key in ("x", "y", "width", "height"):
            value = raw.get(key)
            if type(value) is not int:
                raise PipStateError(f"state file {self.path} has an invalid {key}")
            values[key] = value

        if values["width"] <= 0 or values["height"] <= 0:
            raise PipStateError(
                f"state file {self.path} has a non-positive window size"
            )

        return Geometry(monitor=monitor, **values)

    def save(self, geometry: Geometry) -> None:
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        fd, temporary_name = tempfile.mkstemp(
            dir=self.path.parent,
            prefix=f".{self.path.name}.",
            text=True,
        )
        temporary_path = Path(temporary_name)

        try:
            os.fchmod(fd, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                json.dump(
                    geometry.to_json(), handle, ensure_ascii=False, sort_keys=True
                )
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary_path, self.path)
        finally:
            temporary_path.unlink(missing_ok=True)

    def reset(self) -> None:
        self.path.unlink(missing_ok=True)


class Hyprland:
    def __init__(self, executable: str) -> None:
        self.executable = executable

    def _run(self, *arguments: str) -> str:
        command = [self.executable, *arguments]
        try:
            result = subprocess.run(
                command,
                check=True,
                capture_output=True,
                text=True,
            )
        except OSError as error:
            raise PipStateError(f"cannot execute {self.executable}: {error}") from error
        except subprocess.CalledProcessError as error:
            detail = (error.stderr or error.stdout or "no output").strip()
            raise PipStateError(f"{' '.join(command)} failed: {detail}") from error
        return result.stdout

    def _run_json(self, command: str) -> list[dict[str, Any]]:
        output = self._run(command, "-j")
        try:
            value = json.loads(output)
        except json.JSONDecodeError as error:
            raise PipStateError(
                f"hyprctl {command} returned invalid JSON: {error}"
            ) from error
        if not isinstance(value, list):
            raise PipStateError(f"hyprctl {command} did not return a JSON array")
        return value

    def clients(self) -> list[dict[str, Any]]:
        return self._run_json("clients")

    def monitors(self) -> list[dict[str, Any]]:
        return self._run_json("monitors")

    def restore(self, address: str, monitor: Monitor, geometry: Geometry) -> None:
        selector = f"address:{address}"
        global_x = monitor.x + geometry.x
        global_y = monitor.y + geometry.y
        batch = (
            f"dispatch resizewindowpixel exact {geometry.width} {geometry.height},{selector} ; "
            f"dispatch movewindowpixel exact {global_x} {global_y},{selector}"
        )
        output = self._run("--batch", batch)
        if any(line.lower().startswith("error") for line in output.splitlines()):
            raise PipStateError(
                f"hyprctl rejected PiP geometry restore: {output.strip()}"
            )


class PipTracker:
    def __init__(
        self,
        hyprland: Hyprland,
        store: StateStore,
        save_debounce: float,
    ) -> None:
        self.hyprland = hyprland
        self.store = store
        self.save_debounce = save_debounce
        self.monitors: dict[int, Monitor] = {}
        self.active_address: str | None = None
        self.blocked_address: str | None = None
        self.last_saved: Geometry | None = None
        self.pending: Geometry | None = None
        self.pending_since: float | None = None
        self.multiple_error_active = False

    def refresh_monitors(self) -> None:
        monitors = [Monitor.from_hyprland(raw) for raw in self.hyprland.monitors()]
        self.monitors = {monitor.id: monitor for monitor in monitors}
        if not self.monitors:
            raise PipStateError("Hyprland reported no monitors")

    def _pip_clients(self) -> list[dict[str, Any]]:
        return [
            client
            for client in self.hyprland.clients()
            if client.get("class") == ""
            and client.get("title") in PIP_TITLES
            and client.get("mapped") is True
            and client.get("hidden") is not True
        ]

    def _monitor_for_client(self, client: dict[str, Any]) -> Monitor:
        monitor_id = client.get("monitor")
        if type(monitor_id) is not int:
            raise PipStateError("PiP window has an invalid monitor id")
        if monitor_id not in self.monitors:
            self.refresh_monitors()
        try:
            return self.monitors[monitor_id]
        except KeyError as error:
            raise PipStateError(
                f"PiP window refers to unknown monitor id {monitor_id}"
            ) from error

    def _geometry_for_client(self, client: dict[str, Any]) -> Geometry:
        monitor = self._monitor_for_client(client)
        position = client.get("at")
        size = client.get("size")
        if not self._integer_pair(position) or not self._integer_pair(size):
            raise PipStateError("PiP window has invalid position or size")
        if size[0] <= 0 or size[1] <= 0:
            raise PipStateError("PiP window has a non-positive size")
        return Geometry(
            monitor=monitor.name,
            x=position[0] - monitor.x,
            y=position[1] - monitor.y,
            width=size[0],
            height=size[1],
        )

    @staticmethod
    def _integer_pair(value: Any) -> bool:
        return (
            isinstance(value, list)
            and len(value) == 2
            and all(type(item) is int for item in value)
        )

    def _monitor_by_name(self, name: str) -> Monitor:
        for monitor in self.monitors.values():
            if monitor.name == name:
                return monitor
        raise PipStateError(f"saved PiP monitor {name!r} is not connected")

    @staticmethod
    def _fit_to_monitor(geometry: Geometry, monitor: Monitor) -> Geometry:
        width = min(geometry.width, monitor.width)
        height = min(geometry.height, monitor.height)
        x = min(max(geometry.x, 0), monitor.width - width)
        y = min(max(geometry.y, 0), monitor.height - height)
        return Geometry(monitor=monitor.name, x=x, y=y, width=width, height=height)

    def _initialize(self, client: dict[str, Any]) -> None:
        address = client.get("address")
        if not isinstance(address, str) or not address:
            raise PipStateError("PiP window has an invalid address")
        if client.get("floating") is not True:
            raise PipStateError(f"PiP window {address} is not floating")

        if not self.store.exists():
            geometry = self._geometry_for_client(client)
            self.store.save(geometry)
            log(f"saved initial PiP geometry on {geometry.monitor}")
        else:
            saved = self.store.load()
            monitor = self._monitor_by_name(saved.monitor)
            geometry = self._fit_to_monitor(saved, monitor)
            if geometry != saved:
                log(
                    "adjusted saved PiP geometry to fit monitor "
                    f"{monitor.name}: {saved} -> {geometry}"
                )
            self.hyprland.restore(address, monitor, geometry)
            if geometry != saved:
                self.store.save(geometry)
            log(f"restored PiP geometry on {geometry.monitor}")

        self.active_address = address
        self.blocked_address = None
        self.last_saved = geometry
        self.pending = None
        self.pending_since = None

    def _flush_pending(self) -> None:
        if self.pending is None:
            return
        self.store.save(self.pending)
        self.last_saved = self.pending
        log(f"saved PiP geometry on {self.pending.monitor}")
        self.pending = None
        self.pending_since = None

    def _clear_active(self) -> None:
        self._flush_pending()
        self.active_address = None
        self.last_saved = None
        self.pending = None
        self.pending_since = None

    def _track(self, client: dict[str, Any], now: float) -> None:
        geometry = self._geometry_for_client(client)
        if geometry == self.last_saved:
            self.pending = None
            self.pending_since = None
            return
        if geometry != self.pending:
            self.pending = geometry
            self.pending_since = now
            return
        if (
            self.pending_since is not None
            and now - self.pending_since >= self.save_debounce
        ):
            self._flush_pending()

    def refresh(self) -> bool:
        clients = self._pip_clients()
        if not clients:
            self._clear_active()
            self.blocked_address = None
            self.multiple_error_active = False
            return False

        if len(clients) > 1:
            self._clear_active()
            self.blocked_address = None
            if not self.multiple_error_active:
                log(f"refusing to manage {len(clients)} simultaneous PiP windows")
                self.multiple_error_active = True
            return False

        self.multiple_error_active = False
        client = clients[0]
        address = client.get("address")
        if address == self.blocked_address:
            return False

        if address != self.active_address:
            self._clear_active()
            try:
                self._initialize(client)
            except PipStateError as error:
                log(f"cannot initialize PiP geometry: {error}")
                self.blocked_address = address if isinstance(address, str) else None
                return False
        else:
            try:
                self._track(client, time.monotonic())
            except PipStateError as error:
                log(f"cannot track PiP geometry: {error}")
                self._clear_active()
                self.blocked_address = address if isinstance(address, str) else None
                return False

        return self.active_address is not None

    def shutdown(self) -> None:
        self._flush_pending()


def state_path() -> Path:
    override = os.environ.get("PIP_WINDOW_STATE_FILE")
    if override:
        return Path(override).expanduser()
    state_home = Path(os.environ.get("XDG_STATE_HOME", "~/.local/state")).expanduser()
    return state_home / "hyprland" / "pip-window.json"


def event_socket_path() -> Path:
    override = os.environ.get("PIP_WINDOW_STATE_SOCKET")
    if override:
        return Path(override)

    runtime_dir = os.environ.get("XDG_RUNTIME_DIR")
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not runtime_dir or not signature:
        raise PipStateError(
            "XDG_RUNTIME_DIR and HYPRLAND_INSTANCE_SIGNATURE are required for the Hyprland event socket"
        )
    return Path(runtime_dir) / "hypr" / signature / ".socket2.sock"


def event_name(line: str) -> str:
    return line.split(">>", 1)[0]


def run_daemon(hyprland: Hyprland, store: StateStore) -> None:
    poll_interval = env_float("PIP_WINDOW_STATE_POLL_INTERVAL", 0.25)
    save_debounce = env_float("PIP_WINDOW_STATE_SAVE_DEBOUNCE", 0.5)
    tracker = PipTracker(hyprland, store, save_debounce)
    tracker.refresh_monitors()

    socket_path = event_socket_path()
    event_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        event_socket.connect(str(socket_path))
    except OSError as error:
        event_socket.close()
        raise PipStateError(
            f"cannot connect to Hyprland event socket {socket_path}: {error}"
        ) from error

    def stop(_signum: int, _frame: Any) -> None:
        raise SystemExit(0)

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    buffer = ""
    active = tracker.refresh()
    next_poll = time.monotonic() + poll_interval if active else None

    try:
        while True:
            timeout = (
                None if next_poll is None else max(0.0, next_poll - time.monotonic())
            )
            event_socket.settimeout(timeout)
            try:
                chunk = event_socket.recv(65536)
            except socket.timeout:
                active = tracker.refresh()
                next_poll = time.monotonic() + poll_interval if active else None
                continue

            if not chunk:
                raise PipStateError("Hyprland event socket closed")

            try:
                buffer += chunk.decode("utf-8")
            except UnicodeDecodeError as error:
                raise PipStateError(
                    f"Hyprland event socket returned invalid UTF-8: {error}"
                ) from error

            while "\n" in buffer:
                line, buffer = buffer.split("\n", 1)
                name = event_name(line)
                if name in RELEVANT_MONITOR_EVENTS:
                    tracker.refresh_monitors()
                if name in RELEVANT_MONITOR_EVENTS or name in RELEVANT_WINDOW_EVENTS:
                    active = tracker.refresh()
                    next_poll = time.monotonic() + poll_interval if active else None
    finally:
        event_socket.close()
        tracker.shutdown()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Persist and restore the geometry of the Hyprland browser PiP window."
    )
    parser.add_argument(
        "command", choices=("daemon", "status", "reset"), nargs="?", default="daemon"
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    store = StateStore(state_path())

    if args.command == "status":
        print(
            json.dumps(
                store.load().to_json(), ensure_ascii=False, indent=2, sort_keys=True
            )
        )
        return 0
    if args.command == "reset":
        store.reset()
        print(f"removed PiP geometry state: {store.path}")
        return 0

    hyprctl = os.environ.get("PIP_WINDOW_STATE_HYPRCTL", "hyprctl")
    run_daemon(Hyprland(hyprctl), store)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except PipStateError as error:
        log(str(error))
        raise SystemExit(1) from error
