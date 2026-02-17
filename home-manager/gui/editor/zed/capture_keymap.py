import argparse
import json
import platform
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_AUTO_INPUT = SCRIPT_DIR / "zed-keymap-auto.json"
DEFAULT_MANUAL_OUTPUT = SCRIPT_DIR / "zed-keymap-manual.json"
DEFAULT_FINAL_OUTPUT = SCRIPT_DIR / "zed-keymap.json"


def get_default_zed_keymap_path() -> Optional[Path]:
    home = Path.home()
    system = platform.system()
    if system == "Windows":
        return home / "AppData/Roaming/Zed/keymap.json"
    if system == "Darwin":
        return home / "Library/Application Support/Zed/keymap.json"
    if system == "Linux":
        return home / ".config/zed/keymap.json"
    return None


def strip_jsonc(content: str) -> str:
    output_chars: List[str] = []
    index = 0
    in_string = False
    escaped = False

    while index < len(content):
        current = content[index]

        if in_string:
            output_chars.append(current)
            if escaped:
                escaped = False
            elif current == "\\":
                escaped = True
            elif current == '"':
                in_string = False
            index += 1
            continue

        if current == '"':
            in_string = True
            output_chars.append(current)
            index += 1
            continue

        if current == "/" and index + 1 < len(content):
            nxt = content[index + 1]
            if nxt == "/":
                index += 2
                while index < len(content) and content[index] not in "\r\n":
                    index += 1
                continue
            if nxt == "*":
                index += 2
                while index + 1 < len(content):
                    if content[index] == "*" and content[index + 1] == "/":
                        index += 2
                        break
                    index += 1
                continue

        output_chars.append(current)
        index += 1

    stripped = "".join(output_chars)
    return re.sub(r",\s*([}\]])", r"\1", stripped)


def normalize_entry(entry: Dict[str, Any]) -> Dict[str, Any]:
    if "bindings" not in entry:
        raise ValueError("Each keymap entry must include `bindings`")
    bindings = entry["bindings"]
    if not isinstance(bindings, dict):
        raise ValueError("`bindings` must be an object")

    normalized: Dict[str, Any] = {}
    if "context" in entry:
        normalized["context"] = entry["context"]
    if "use_key_equivalents" in entry:
        normalized["use_key_equivalents"] = entry["use_key_equivalents"]

    normalized["bindings"] = {key: bindings[key] for key in sorted(bindings.keys())}

    for key in sorted(entry.keys()):
        if key in normalized or key == "bindings":
            continue
        normalized[key] = entry[key]
    return normalized


def normalize_keymap(data: Any) -> List[Dict[str, Any]]:
    if not isinstance(data, list):
        raise ValueError("Keymap root must be a list")

    normalized_list: List[Dict[str, Any]] = []
    for entry in data:
        if not isinstance(entry, dict):
            raise ValueError("Each keymap entry must be an object")
        normalized_list.append(normalize_entry(entry))
    return normalized_list


def ordered_contexts(
    contexts: List[Optional[str]],
    preferred_context_order: List[Optional[str]],
) -> List[Optional[str]]:
    preferred = [None, "Workspace", "Editor", "Editor && mode == full", "Terminal", "menu"]
    ordered: List[Optional[str]] = []
    for context in preferred_context_order + preferred:
        if context in contexts and context not in ordered:
            ordered.append(context)
    for context in sorted(c for c in contexts if c is not None):
        if context not in ordered:
            ordered.append(context)
    return ordered


def build_output(
    grouped: Dict[Optional[str], Dict[str, Any]],
    preferred_context_order: List[Optional[str]],
) -> List[Dict[str, Any]]:
    output: List[Dict[str, Any]] = []
    for context in ordered_contexts(list(grouped.keys()), preferred_context_order):
        bindings = grouped[context]
        ordered_bindings = {key: bindings[key] for key in sorted(bindings.keys())}
        if context is None:
            output.append({"bindings": ordered_bindings})
        else:
            output.append({"context": context, "bindings": ordered_bindings})
    return output


def keymap_to_grouped(data: List[Dict[str, Any]]) -> Tuple[Dict[Optional[str], Dict[str, Any]], List[Optional[str]]]:
    grouped: Dict[Optional[str], Dict[str, Any]] = {}
    context_order: List[Optional[str]] = []
    for entry in data:
        bindings = entry.get("bindings")
        if not isinstance(bindings, dict):
            continue
        raw_context = entry.get("context")
        context: Optional[str] = raw_context if isinstance(raw_context, str) and raw_context else None
        if context not in context_order:
            context_order.append(context)
        grouped.setdefault(context, {})
        grouped[context].update(bindings)
    return grouped, context_order


def merge_grouped(
    base: Dict[Optional[str], Dict[str, Any]],
    overlay: Dict[Optional[str], Dict[str, Any]],
) -> Dict[Optional[str], Dict[str, Any]]:
    merged: Dict[Optional[str], Dict[str, Any]] = {
        context: dict(bindings)
        for context, bindings in base.items()
    }
    for context, bindings in overlay.items():
        merged.setdefault(context, {})
        merged[context].update(bindings)
    return merged


def compute_manual_overrides(
    auto_grouped: Dict[Optional[str], Dict[str, Any]],
    captured_grouped: Dict[Optional[str], Dict[str, Any]],
) -> Tuple[Dict[Optional[str], Dict[str, Any]], List[Optional[str]]]:
    overrides: Dict[Optional[str], Dict[str, Any]] = {}
    context_order: List[Optional[str]] = []
    missing = object()

    for context, captured_bindings in captured_grouped.items():
        auto_bindings = auto_grouped.get(context, {})
        for key, value in captured_bindings.items():
            auto_value = auto_bindings.get(key, missing)
            if auto_value != value:
                overrides.setdefault(context, {})
                overrides[context][key] = value
                if context not in context_order:
                    context_order.append(context)

    return overrides, context_order


def flatten_keymap(data: List[Dict[str, Any]]) -> Dict[Tuple[str, str], str]:
    flattened: Dict[Tuple[str, str], str] = {}
    for entry in data:
        context = str(entry.get("context", ""))
        bindings = entry.get("bindings", {})
        if not isinstance(bindings, dict):
            continue
        for key, value in bindings.items():
            flattened[(context, key)] = json.dumps(value, ensure_ascii=False, sort_keys=True)
    return flattened


def summarize_changes(before: List[Dict[str, Any]], after: List[Dict[str, Any]]) -> Tuple[int, int, int]:
    before_map = flatten_keymap(before)
    after_map = flatten_keymap(after)

    added = len(set(after_map.keys()) - set(before_map.keys()))
    removed = len(set(before_map.keys()) - set(after_map.keys()))
    changed = 0
    for key in set(before_map.keys()) & set(after_map.keys()):
        if before_map[key] != after_map[key]:
            changed += 1
    return added, removed, changed


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def load_jsonc(path: Path) -> Any:
    content = path.read_text(encoding="utf-8")
    content = content.lstrip("\ufeff")
    json_text = strip_jsonc(content)
    return json.loads(json_text)


def load_json_if_exists(path: Path) -> List[Dict[str, Any]]:
    if not path.exists():
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    return normalize_keymap(data)


def count_bindings(data: List[Dict[str, Any]]) -> int:
    total = 0
    for entry in data:
        bindings = entry.get("bindings", {})
        if isinstance(bindings, dict):
            total += len(bindings)
    return total


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Capture tested Zed keymap into manual overrides and rebuild final keymap"
    )
    parser.add_argument("--input", help="Path to current Zed keymap.json (JSON/JSONC)")
    parser.add_argument(
        "--auto-input",
        default=str(DEFAULT_AUTO_INPUT),
        help=f"Path to auto-generated keymap baseline (default: {DEFAULT_AUTO_INPUT})",
    )
    parser.add_argument(
        "--manual-output",
        default=str(DEFAULT_MANUAL_OUTPUT),
        help=f"Path to repository-managed manual overrides (default: {DEFAULT_MANUAL_OUTPUT})",
    )
    parser.add_argument(
        "--final-output",
        default=str(DEFAULT_FINAL_OUTPUT),
        help=f"Path to repository-managed final keymap (default: {DEFAULT_FINAL_OUTPUT})",
    )
    args = parser.parse_args()

    if args.input:
        source = Path(args.input).expanduser().resolve()
    else:
        default_source = get_default_zed_keymap_path()
        if default_source is None:
            raise RuntimeError("Unsupported platform for default Zed keymap path")
        source = default_source

    if not source.exists():
        raise FileNotFoundError(f"Zed keymap file not found: {source}")

    auto_input = Path(args.auto_input).expanduser().resolve()
    manual_output = Path(args.manual_output).expanduser().resolve()
    final_output = Path(args.final_output).expanduser().resolve()

    captured_data = normalize_keymap(load_jsonc(source))

    auto_data: List[Dict[str, Any]] = []
    if auto_input.exists():
        auto_data = load_json_if_exists(auto_input)
    else:
        print(f"Auto keymap not found, using empty baseline: {auto_input}")

    previous_manual_data = load_json_if_exists(manual_output)

    auto_grouped, auto_context_order = keymap_to_grouped(auto_data)
    captured_grouped, _ = keymap_to_grouped(captured_data)

    manual_grouped, manual_context_order = compute_manual_overrides(
        auto_grouped=auto_grouped,
        captured_grouped=captured_grouped,
    )

    manual_data = build_output(manual_grouped, manual_context_order)
    write_json(manual_output, manual_data)

    final_grouped = merge_grouped(auto_grouped, manual_grouped)
    final_context_order = auto_context_order.copy()
    for context in manual_context_order:
        if context not in final_context_order:
            final_context_order.append(context)
    final_data = build_output(final_grouped, final_context_order)
    write_json(final_output, final_data)

    added, removed, changed = summarize_changes(previous_manual_data, manual_data)
    override_count = count_bindings(manual_data)

    print(f"Captured keymap from: {source}")
    print(f"Auto baseline: {auto_input}")
    print(f"Wrote manual overrides: {manual_output}")
    print(f"Wrote final keymap: {final_output}")
    print(f"Manual override summary: overrides={override_count} added={added} removed={removed} changed={changed}")
    print("Note: Explicit key overrides are captured. Removing an auto-generated key by omission is not represented.")


if __name__ == "__main__":
    main()
