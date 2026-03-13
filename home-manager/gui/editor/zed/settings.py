import argparse
import json
import platform
import re
from pathlib import Path
from typing import Any, Optional


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_OUTPUTS = {
    "Darwin": SCRIPT_DIR / "zed-settings-darwin.json",
    "Linux": SCRIPT_DIR / "zed-settings-linux.json",
}


def get_default_zed_settings_path() -> Optional[Path]:
    home = Path.home()
    system = platform.system()
    if system == "Windows":
        return home / "AppData/Roaming/Zed/settings.json"
    if system == "Darwin":
        return home / "Library/Application Support/Zed/settings.json"
    if system == "Linux":
        return home / ".config/zed/settings.json"
    return None


def get_default_output_path() -> Optional[Path]:
    return DEFAULT_OUTPUTS.get(platform.system())


def strip_jsonc(content: str) -> str:
    output_chars = []
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


def normalize_settings(value: Any) -> Any:
    if isinstance(value, dict):
        return {
            key: normalize_settings(value[key])
            for key in sorted(value.keys())
        }
    if isinstance(value, list):
        return [normalize_settings(item) for item in value]
    return value


def read_settings(path: Path) -> Any:
    return json.loads(strip_jsonc(path.read_text(encoding="utf-8")))


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Capture the current Zed settings.json into a platform-specific repo file"
    )
    parser.add_argument("--input", help="Path to Zed settings.json")
    parser.add_argument("--output", help="Path to captured repo JSON file")
    args = parser.parse_args()

    source = Path(args.input).expanduser().resolve() if args.input else get_default_zed_settings_path()
    if source is None:
        print("Unsupported platform for Zed settings sync.")
        raise SystemExit(1)
    if not source.exists():
        print(f"Zed settings.json not found: {source}")
        raise SystemExit(1)

    output = Path(args.output).expanduser().resolve() if args.output else get_default_output_path()
    if output is None:
        print("Unsupported platform for repo output path.")
        raise SystemExit(1)

    settings = normalize_settings(read_settings(source))
    if not isinstance(settings, dict):
        print("Expected Zed settings root to be an object.")
        raise SystemExit(1)

    write_json(output, settings)
    print(f"Captured Zed settings from {source}")
    print(f"Wrote Zed settings to {output}")


if __name__ == "__main__":
    main()
