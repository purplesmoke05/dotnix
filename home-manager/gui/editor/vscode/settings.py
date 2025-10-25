import json
import os
import shutil
import platform
import argparse
from pathlib import Path
from typing import Dict, Any, Optional
import re


def get_cursor_settings_path() -> Optional[Path]:
    """Get the path to Cursor settings.json based on the operating system."""
    home = Path.home()

    if platform.system() == "Windows":
        return home / "AppData/Roaming/Cursor/User/settings.json"
    elif platform.system() == "Darwin":  # macOS
        return home / "Library/Application Support/Cursor/User/settings.json"
    elif platform.system() == "Linux":
        return home / ".config/Cursor/User/settings.json"
    return None


def get_vscode_settings_path() -> Optional[Path]:
    """Get the path to VSCode settings.json based on the operating system."""
    home = Path.home()

    if platform.system() == "Windows":
        return home / "AppData/Roaming/Code/User/settings.json"
    elif platform.system() == "Darwin":  # macOS
        return home / "Library/Application Support/Code/User/settings.json"
    elif platform.system() == "Linux":
        return home / ".config/Code/User/settings.json"
    return None


def get_settings_source_path(source: Optional[str] = None) -> Optional[Path]:
    """Get the appropriate settings path based on platform preference or explicit source."""
    if source == "vscode":
        return get_vscode_settings_path()
    elif source == "cursor":
        return get_cursor_settings_path()
    else:
        # Auto-select based on platform (original behavior)
        if platform.system() == "Darwin":  # macOS
            # On macOS, prefer VSCode settings
            vscode_path = get_vscode_settings_path()
            if vscode_path and vscode_path.exists():
                return vscode_path
            # Fallback to Cursor if VSCode not found
            return get_cursor_settings_path()
        else:
            # On Linux/Windows, prefer Cursor settings
            cursor_path = get_cursor_settings_path()
            if cursor_path and cursor_path.exists():
                return cursor_path
            # Fallback to VSCode if Cursor not found
            return get_vscode_settings_path()


NIX_IDENTIFIER_PATTERN = r"^[a-zA-Z_][a-zA-Z0-9_'-]*$"


def is_dottable_key(key: str) -> bool:
    """Return True when the key should be expanded into nested attrs."""

    if '.' not in key or key.startswith('.') or key.endswith('.'):
        return False

    segments = key.split('.')
    return all(segment and re.fullmatch(NIX_IDENTIFIER_PATTERN, segment) for segment in segments)


class SettingsConverter:
    def __init__(self, input_file: str, output_file: str):
        self.input_file = input_file
        self.output_file = output_file

    def _escape_string(self, value: str) -> str:
        """Escape special characters in string values."""
        # Escape backslashes first, then quotes
        # Also escape ${ to prevent Nix string interpolation
        return value.replace('\\', '\\\\').replace('"', '\\"').replace('${', '\\${')

    def _format_value(self, value: Any) -> str:
        """Format value based on its type."""
        if isinstance(value, str):
            return f'"{self._escape_string(value)}"'
        elif isinstance(value, list):
            items = [self._format_value(item) for item in value]
            return f"[\n    {' '.join(items)}\n  ]"
        elif value is None:
            return '""'
        elif isinstance(value, bool):
            return str(value).lower()
        elif isinstance(value, (int, float)):
            return str(value)
        elif isinstance(value, dict):
            return self._format_dict(value)
        return json.dumps(value)

    def _format_dict(self, d: Dict[str, Any], indent: int = 2) -> str:
        """Format a dictionary as Nix attributes."""
        lines = ["{"]
        spaces = " " * indent
        for key, value in d.items():
            formatted_value = self._format_value(value)

            # Revised logic for formatting keys:
            # Check if the key is a valid Nix identifier or valid dotted path
            if is_dottable_key(key):
                formatted_key = key
            else:
                # Single segment key
                if re.fullmatch(NIX_IDENTIFIER_PATTERN, key):
                    formatted_key = key  # Valid identifier
                else:
                    # Not a valid identifier (e.g., "*", "123"), quote it.
                    escaped_key = key.replace('\\\\', '\\\\\\\\').replace('"', '\\"').replace('${', '\\\\${')
                    formatted_key = f'"{escaped_key}"'

            lines.append(f"{spaces}{formatted_key} = {formatted_value};")
        lines.append(f"{' ' * (indent-2)}}}")
        return "\n".join(lines)

    def _deep_merge(self, base: Dict[str, Any], incoming: Dict[str, Any]) -> Dict[str, Any]:
        """Recursively merge two dictionaries."""
        merged = dict(base)
        for key, value in incoming.items():
            if key in merged and isinstance(merged[key], dict) and isinstance(value, dict):
                merged[key] = self._deep_merge(merged[key], value)
            else:
                merged[key] = value
        return merged

    def _merge_dotted_keys(self, settings: Dict[str, Any]) -> Dict[str, Any]:
        """Merge dotted keys (e.g., 'foo.bar': value) into nested structure."""
        result: Dict[str, Any] = {}

        for key, value in settings.items():
            if isinstance(value, dict):
                value = self._merge_dotted_keys(value)

            if not is_dottable_key(key):
                if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                    result[key] = self._deep_merge(result[key], value)
                else:
                    result[key] = value
                continue

            parts = key.split('.')
            current = result
            skip_assignment = False
            for index, part in enumerate(parts[:-1]):
                if part not in current:
                    current[part] = {}
                elif not isinstance(current[part], dict):
                    partial_path = '.'.join(parts[: index + 1])
                    print(f"Warning: Cannot merge '{key}' - '{partial_path}' is not a dictionary")
                    skip_assignment = True
                    break
                current = current[part]

            if skip_assignment or not isinstance(current, dict):
                continue

            final_key = parts[-1]
            existing = current.get(final_key)
            if isinstance(existing, dict) and isinstance(value, dict):
                current[final_key] = self._deep_merge(existing, value)
            else:
                current[final_key] = value

        return result

    def _read_json(self) -> Optional[Dict[str, Any]]:
        """Read and parse JSON file."""
        try:
            with open(self.input_file, 'r', encoding='utf-8') as f:
                return json.loads(f.read())
        except json.JSONDecodeError as e:
            print(f"JSON parse error: {e}")
            print(f"Please check the contents of file '{self.input_file}'")
            return None
        except Exception as e:
            print(f"Error reading file: {e}")
            return None

    def _write_nix(self, content: str) -> bool:
        """Write content to Nix file."""
        try:
            with open(self.output_file, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        except Exception as e:
            print(f"Error writing file: {e}")
            return False

    def convert(self) -> bool:
        """Convert JSON settings to Nix format."""
        settings = self._read_json()
        if settings is None:
            return False

        # Merge dotted keys to prevent duplicates
        merged_settings = self._merge_dotted_keys(settings)

        # Convert to Nix format
        nix_content = self._format_dict(merged_settings)

        # Write to file
        return self._write_nix(nix_content)


def main():
    """Main entry point."""
    # Environment override to force skipping (e.g., from wrapper scripts/CI)
    if os.getenv('UPDATE_SKIP_VSCODE', '').lower() in ('1', 'true', 'yes'):
        print('Skipping VSCode settings sync due to UPDATE_SKIP_VSCODE env')
        return
    parser = argparse.ArgumentParser(description='Convert VSCode/Cursor settings to Nix format')
    parser.add_argument('--source', choices=['vscode', 'cursor'],
                       help='Specify settings source (vscode or cursor). If not specified, auto-detect based on platform.')
    args = parser.parse_args()

    current_dir = os.path.dirname(os.path.abspath(__file__))
    input_file = os.path.join(current_dir, 'cursor-settings.json')
    output_file = os.path.join(current_dir, 'settings.nix')

    # Get appropriate settings source
    settings_source = get_settings_source_path(args.source)
    print(settings_source)
    if settings_source and settings_source.exists():
        try:
            shutil.copy2(settings_source, input_file)
            os.chmod(input_file, 0o644)
            source_name = "VSCode" if "Code" in str(settings_source) else "Cursor"
            source_specified = f" (--source {args.source})" if args.source else " (auto-detected)"
            print(f"Copied settings from {source_name}{source_specified}: {settings_source}")
        except Exception as e:
            print(f"Error copying settings file: {e}")
            exit(1)
    else:
        if args.source:
            print(f"Specified {args.source} settings.json not found")
        else:
            print("No VSCode/Cursor settings.json found")
        exit(1)

    # Convert to Nix format
    converter = SettingsConverter(input_file, output_file)
    if converter.convert():
        print("Conversion completed successfully!")
    else:
        print("Conversion failed.")
        exit(1)


if __name__ == "__main__":
    main()
