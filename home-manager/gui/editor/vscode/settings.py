import json
import os
import shutil
import platform
from pathlib import Path
from typing import Dict, Any, Optional

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

class SettingsConverter:
    def __init__(self, input_file: str, output_file: str):
        self.input_file = input_file
        self.output_file = output_file

    def _escape_string(self, value: str) -> str:
        """Escape special characters in string values."""
        return value.replace('\\', '\\\\').replace('"', '\\"')

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
            lines.append(f"{spaces}{key} = {formatted_value};")
        lines.append(f"{' ' * (indent-2)}}}")
        return "\n".join(lines)

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

        # Convert to Nix format
        nix_content = self._format_dict(settings)

        # Write to file
        return self._write_nix(nix_content)

def main():
    """Main entry point."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    input_file = os.path.join(current_dir, 'cursor-settings.json')
    output_file = os.path.join(current_dir, 'settings.nix')

    # Copy Cursor settings.json to current directory
    cursor_settings = get_cursor_settings_path()
    if cursor_settings and cursor_settings.exists():
        try:
            shutil.copy2(cursor_settings, input_file)
            os.chmod(input_file, 0o644)
            print(f"Copied settings from: {cursor_settings}")
        except Exception as e:
            print(f"Error copying settings file: {e}")
            exit(1)
    else:
        print("Cursor settings.json not found")

    # Convert to Nix format
    converter = SettingsConverter(input_file, output_file)
    if converter.convert():
        print("Conversion completed successfully!")
    else:
        print("Conversion failed.")
        exit(1)

if __name__ == "__main__":
    main()
