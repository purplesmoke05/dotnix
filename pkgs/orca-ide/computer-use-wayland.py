#!/usr/bin/env python3
"""Wayland-capable Orca Computer Use provider for Hyprland.

Orca's bundled Linux provider drives the desktop through AT-SPI, whose registry
daemon synthesizes input with XTest. A Wayland session gives that daemon no X
display, so its synthetic input never reaches native Wayland windows; the
bundled provider also disables screenshots and hotkeys when it detects
XDG_SESSION_TYPE=wayland.

This provider loads the bundled runtime.py unchanged and replaces only the
functions that need Wayland-native tools:

  capture_png    -> grim
  type_text      -> wtype
  press_key      -> dotool
  hotkey         -> dotool
  click/scroll/drag -> hyprctl movecursor + dotool
  restore_window -> AT-SPI grab_focus, then hyprctl focuswindow

It is wired in through ORCA_COMPUTER_DESKTOP_SCRIPT_PROVIDER_PATH, so the
upstream file stays byte-for-byte intact and `make update` needs no patch
rebasing. REQUIRED_UPSTREAM is asserted at load time; if a future release
renames one of those functions this provider fails loudly, and the package's
installCheck catches it during the build.
"""

import importlib.util
import json
import math
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

BUNDLED_RUNTIME = str(
    Path(__file__).resolve().parent.parent / "lib" / "Orca" / "resources" / "computer-use-linux" / "runtime.py"
)

REQUIRED_UPSTREAM = (
    "capture_png",
    "click_at",
    "drag_between",
    "handshake_response",
    "hotkey",
    "key_name",
    "main",
    "press_key",
    "restore_window",
    "screen_rect",
    "run_operation",
    "scroll_at",
    "type_text",
)

# dotool supports exactly these modifier names; X11-style aliases map onto them.
MODIFIER_ALIASES = {
    "ctrl": "ctrl",
    "control": "ctrl",
    "cmdorctrl": "ctrl",
    "commandorcontrol": "ctrl",
    "shift": "shift",
    "alt": "alt",
    "option": "alt",
    "altgr": "altgr",
    "super": "super",
    "meta": "super",
    "win": "super",
    "logo": "super",
    "cmd": "super",
    "command": "super",
}

# XKB names this layout does not expose under their canonical spelling.
DOTOOL_KEY_OVERRIDES = {
    "Page_Up": "k:104",
    "Page_Down": "k:105",
}

MOUSE_BUTTONS = {"left": "left", "middle": "middle", "right": "right"}

CAPTURE_TIMEOUT_SECONDS = 15
KEYSTROKE_TIMEOUT_SECONDS = 15
TYPE_TIMEOUT_SECONDS = 30
POINTER_TIMEOUT_SECONDS = 15


def load_bundled():
    spec = importlib.util.spec_from_file_location("orca_bundled_runtime", BUNDLED_RUNTIME)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load bundled runtime: {BUNDLED_RUNTIME}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    missing = [name for name in REQUIRED_UPSTREAM if not hasattr(module, name)]
    if missing:
        raise RuntimeError(
            "bundled runtime.py no longer defines: "
            + ", ".join(missing)
            + "; update pkgs/orca-ide/computer-use-wayland.py for this Orca release"
        )
    return module


runtime = load_bundled()

UPSTREAM = {
    name: getattr(runtime, name)
    for name in (
        "click_at",
        "drag_between",
        "handshake_response",
        "hotkey",
        "press_key",
        "restore_window",
        "screen_rect",
        "scroll_at",
        "type_text",
    )
}


def grim():
    return shutil.which("grim")


def wtype():
    return shutil.which("wtype")


def dotool():
    return shutil.which("dotool")


def hyprctl():
    return shutil.which("hyprctl")


def run_dotool(actions):
    binary = dotool()
    if not binary:
        raise RuntimeError("dotool is required for Wayland input synthesis")
    payload = "".join(f"{action}\n" for action in actions)
    result = subprocess.run(
        [binary],
        input=payload,
        text=True,
        capture_output=True,
        timeout=KEYSTROKE_TIMEOUT_SECONDS,
    )
    if result.returncode != 0:
        raise RuntimeError(f"dotool failed: {result.stderr.strip() or result.stdout.strip()}")


def move_cursor(x, y):
    binary = hyprctl()
    signature = instance_signature()
    if not binary or not signature:
        raise RuntimeError("hyprctl is required to position the pointer on Wayland")
    result = subprocess.run(
        [binary, "-i", signature, "dispatch", "movecursor", str(round(x)), str(round(y))],
        capture_output=True,
        text=True,
        timeout=POINTER_TIMEOUT_SECONDS,
    )
    if result.returncode != 0 or "ok" not in result.stdout.lower():
        raise RuntimeError(f"hyprctl movecursor failed for ({round(x)}, {round(y)})")


def capture_png(rect):
    """Capture rect with grim, then reuse upstream's payload bounding."""
    grim_bin = grim()
    if rect is None or not grim_bin:
        return None
    geometry = "{},{} {}x{}".format(
        round(rect.x),
        round(rect.y),
        max(1, round(rect.width)),
        max(1, round(rect.height)),
    )
    # Scale 1 keeps grim pixels aligned with the AT-SPI logical coordinates the agent reasons about.
    try:
        result = subprocess.run(
            [grim_bin, "-s", "1", "-g", geometry, "-t", "png", "-"],
            capture_output=True,
            timeout=CAPTURE_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"error": {"code": "screenshot_failed", "message": f"grim failed: {exc}"}}
    if result.returncode != 0 or not result.stdout:
        detail = result.stderr.decode("utf-8", "replace").strip() or "no PNG on stdout"
        return {"error": {"code": "screenshot_failed", "message": f"grim failed: {detail}"}}

    pixbuf_type = getattr(runtime, "GdkPixbuf", None)
    if pixbuf_type is None:
        return {"error": {"code": "screenshot_failed", "message": "GdkPixbuf is unavailable for decoding"}}
    loader = pixbuf_type.PixbufLoader()
    try:
        loader.write(result.stdout)
        loader.close()
        pixbuf = loader.get_pixbuf()
    except Exception as exc:  # noqa: BLE001 - report any decode failure to the agent
        return {"error": {"code": "screenshot_failed", "message": f"PNG decode failed: {exc}"}}
    if pixbuf is None:
        return {"error": {"code": "screenshot_failed", "message": "PNG decode produced no pixbuf"}}
    return runtime.bounded_png_payload(pixbuf)


def type_text(value):
    wtype_bin = wtype()
    if not wtype_bin:
        return UPSTREAM["type_text"](value)
    # Feed stdin so leading dashes and multi-line text never hit wtype's option parser.
    result = subprocess.run(
        [wtype_bin, "-"],
        input=str(value),
        text=True,
        capture_output=True,
        timeout=TYPE_TIMEOUT_SECONDS,
    )
    if result.returncode != 0:
        raise RuntimeError(f"wtype failed to type text: {result.stderr.strip()}")


def dotool_key_spec(name):
    if name in DOTOOL_KEY_OVERRIDES:
        return DOTOOL_KEY_OVERRIDES[name]
    if len(name) == 1 and name.isalnum():
        return name
    return f"x:{name}"


def press_key(raw):
    if not dotool():
        return UPSTREAM["press_key"](raw)
    run_dotool([f"key {dotool_key_spec(runtime.key_name(raw))}"])


def hotkey(raw):
    if not dotool():
        return UPSTREAM["hotkey"](raw)
    key_spec = re.sub(r"(?i)commandorcontrol|cmdorctrl", "ctrl", str(raw))
    parts = [part.strip() for part in key_spec.split("+") if part.strip()]
    if not parts:
        raise RuntimeError("hotkey requires a key")
    modifiers = []
    for modifier in parts[:-1]:
        mapped = MODIFIER_ALIASES.get(modifier.lower())
        if mapped is None:
            raise RuntimeError(f"unsupported hotkey modifier: {modifier}")
        if mapped not in modifiers:
            modifiers.append(mapped)
    chord = "+".join([*modifiers, dotool_key_spec(runtime.key_name(parts[-1]))])
    run_dotool([f"key {chord}"])


CLIENTS_UNAVAILABLE = object()
_clients_cache = None
_offset_cache = {}


def instance_signature():
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if signature:
        return signature
    binary = hyprctl()
    if not binary:
        return None
    result = subprocess.run(
        [binary, "-j", "instances"],
        capture_output=True,
        text=True,
        timeout=POINTER_TIMEOUT_SECONDS,
    )
    if result.returncode != 0:
        return None
    try:
        instances = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None
    if not instances:
        return None
    return instances[0].get("instance")


def hyprctl_json(*args):
    binary = hyprctl()
    signature = instance_signature()
    if not binary or not signature:
        return CLIENTS_UNAVAILABLE
    result = subprocess.run(
        [binary, "-i", signature, "-j", *args],
        capture_output=True,
        text=True,
        timeout=POINTER_TIMEOUT_SECONDS,
    )
    if result.returncode != 0:
        return CLIENTS_UNAVAILABLE
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return CLIENTS_UNAVAILABLE


def compositor_clients():
    global _clients_cache
    if _clients_cache is None:
        _clients_cache = hyprctl_json("clients")
    return _clients_cache


def compositor_offset(node):
    """Window offset that turns AT-SPI window-relative coordinates into global ones.

    On Wayland the accessibility tree reports a window at (0, 0) and every
    descendant relative to it, so the compositor is the only source of the real
    window position. Ancestors are matched by reported size against the
    compositor's client list, which needs no role names and yields a zero offset
    on X11 where AT-SPI already reports global coordinates.
    """
    if node is None:
        return 0.0, 0.0
    clients = compositor_clients()
    pid = runtime.pid_of(node)
    own_rect = UPSTREAM["screen_rect"](node)
    if own_rect is not None:
        cache_key = (pid, round(own_rect.width), round(own_rect.height))
        cached = _offset_cache.get(cache_key)
        if cached is not None:
            return cached
    offset = (0.0, 0.0)
    if clients is not CLIENTS_UNAVAILABLE and pid:
        same_pid = [client for client in clients if client.get("pid") == pid]
        current = node
        while current is not None and offset == (0.0, 0.0):
            rect = UPSTREAM["screen_rect"](current)
            if rect is not None:
                for client in same_pid:
                    at = client.get("at") or [None, None]
                    size = client.get("size") or [None, None]
                    if None in at or None in size:
                        continue
                    if round(size[0]) == round(rect.width) and round(size[1]) == round(rect.height):
                        offset = (float(at[0]) - rect.x, float(at[1]) - rect.y)
                        break
            current = runtime.attempt(current.get_parent)
    if own_rect is not None:
        _offset_cache[cache_key] = offset
    return offset


def screen_rect(node):
    rect = UPSTREAM["screen_rect"](node)
    if rect is None:
        return None
    offset_x, offset_y = compositor_offset(node)
    return runtime.Rect(rect.x + offset_x, rect.y + offset_y, rect.width, rect.height)


def click_at(x, y, button, count, modifiers=None):
    if not dotool() or not hyprctl() or modifiers:
        return UPSTREAM["click_at"](x, y, button, count, modifiers)
    resolved = MOUSE_BUTTONS.get((button or "left").lower())
    if resolved is None:
        raise RuntimeError(f"unsupported mouse button: {button}")
    presses = max(1, int(runtime.require_positive_integer(1 if count is None else count, "click_count")))
    move_cursor(x, y)
    run_dotool([f"click {resolved}"] * presses)


def scroll_at(x, y, direction, pages):
    if not dotool() or not hyprctl():
        return UPSTREAM["scroll_at"](x, y, direction, pages)
    if direction is None or str(direction).strip() == "":
        raise RuntimeError("direction is required")
    direction = str(direction).lower()
    axes = {"up": "wheel", "down": "wheel", "left": "hwheel", "right": "hwheel"}
    if direction not in axes:
        raise RuntimeError(f"unsupported scroll direction: {direction}")
    steps = max(1, math.ceil(runtime.require_positive_number(1 if pages is None else pages, "pages")))
    amount = -steps if direction in ("up", "left") else steps
    move_cursor(x, y)
    run_dotool([f"{axes[direction]} {amount}"])


def drag_between(start, end):
    if not dotool() or not hyprctl():
        return UPSTREAM["drag_between"](start, end)
    move_cursor(*start)
    run_dotool(["buttondown left"])
    try:
        for step in range(1, 13):
            x = start[0] + (end[0] - start[0]) * step / 12
            y = start[1] + (end[1] - start[1]) * step / 12
            move_cursor(x, y)
    finally:
        run_dotool(["buttonup left"])


def restore_window(app, window=None):
    UPSTREAM["restore_window"](app, window)
    if window is not None and runtime.has_state(window, runtime.Atspi.StateType.ACTIVE):
        return
    binary = hyprctl()
    signature = instance_signature()
    clients = compositor_clients()
    pid = runtime.pid_of(app)
    if not binary or not signature or not pid or clients is CLIENTS_UNAVAILABLE:
        return
    rect = UPSTREAM["screen_rect"](window) if window is not None else None
    for client in clients:
        if client.get("pid") != pid:
            continue
        if rect is not None:
            size = client.get("size") or [None, None]
            if None in size or round(size[0]) != round(rect.width) or round(size[1]) != round(rect.height):
                continue
        address = client.get("address")
        if not address:
            continue
        subprocess.run(
            [binary, "-i", signature, "dispatch", "focuswindow", f"address:{address}"],
            check=False,
            capture_output=True,
            timeout=POINTER_TIMEOUT_SECONDS,
        )
        return


def handshake_response():
    capabilities = UPSTREAM["handshake_response"]()
    supports = capabilities["supports"]
    if grim():
        supports["observation"]["screenshot"] = True
    if dotool():
        supports["actions"]["hotkey"] = True
    if wtype():
        supports["actions"]["pasteText"] = supports["actions"]["pasteText"] or bool(
            shutil.which("wl-copy") or shutil.which("xclip") or shutil.which("xsel")
        )
    return capabilities


def install_overrides():
    runtime.capture_png = capture_png
    runtime.click_at = click_at
    runtime.drag_between = drag_between
    runtime.handshake_response = handshake_response
    runtime.hotkey = hotkey
    runtime.press_key = press_key
    runtime.restore_window = restore_window
    runtime.screen_rect = screen_rect
    runtime.scroll_at = scroll_at
    runtime.type_text = type_text


if __name__ == "__main__":
    install_overrides()
    runtime.main()
