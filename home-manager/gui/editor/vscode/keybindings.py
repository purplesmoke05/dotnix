import json
import os
import shutil
import platform
from pathlib import Path
from typing import Dict, Any, List, Optional

def get_cursor_keybindings_path() -> Optional[Path]:
    """Get the path to Cursor keybindings.json based on the operating system."""
    home = Path.home()
    
    if platform.system() == "Windows":
        return home / "AppData/Roaming/Cursor/User/keybindings.json"
    elif platform.system() == "Darwin":  # macOS
        return home / "Library/Application Support/Cursor/User/keybindings.json"
    elif platform.system() == "Linux":
        return home / ".config/Cursor/User/keybindings.json"
    return None

class KeybindingsConverter:
    def __init__(self, input_file: str, output_file: str):
        self.input_file = input_file
        self.output_file = output_file
        self.nix_template = {
            'header': "[",
            'footer': "  ]"
        }

    def _escape_string(self, value: str) -> str:
        """Escape special characters in string values."""
        return value.replace('\\', '\\\\').replace('"', '\\"')

    def _format_value(self, value: Any) -> str:
        """Format value based on its type."""
        if isinstance(value, str):
            return f'"{self._escape_string(value)}"'
        elif value is None:
            return '""'
        return json.dumps(value)

    def _format_binding(self, binding: Dict[str, Any], is_last: bool = False) -> str:
        """Format a single keybinding entry."""
        lines = ["    {"]
        for key, value in binding.items():
            formatted_value = self._format_value(value)
            lines.append(f'      {key} = {formatted_value};')
        lines.append("    }")
        return "\n".join(lines)

    def _read_json(self) -> Optional[List[Dict[str, Any]]]:
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
        """Convert JSON keybindings to Nix format."""
        keybindings = self._read_json()
        if keybindings is None:
            return False

        # Build Nix content
        nix_content = [self.nix_template['header']]
        for i, binding in enumerate(keybindings):
            is_last = i == len(keybindings) - 1
            nix_content.append(self._format_binding(binding, is_last))
        nix_content.append(self.nix_template['footer'])

        # Write to file
        return self._write_nix('\n'.join(nix_content))

def main():
    """Main entry point."""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    input_file = os.path.join(current_dir, 'cursor-keybindings.json')
    output_file = os.path.join(current_dir, 'keybindings.nix')

    # Copy VSCode keybindings.json to current directory
    cursor_keybindings = get_cursor_keybindings_path()
    if cursor_keybindings and cursor_keybindings.exists():
        try:
            shutil.copy2(cursor_keybindings, input_file)
            os.chmod(input_file, 0o644)
            print(f"Copied keybindings from: {cursor_keybindings}")
        except Exception as e:
            print(f"Error copying keybindings file: {e}")
            exit(1)
    else:
        print("VSCode keybindings.json not found")
        exit(1)

    # Convert to Nix format
    converter = KeybindingsConverter(input_file, output_file)
    if converter.convert():
        print("Conversion completed successfully!")
    else:
        print("Conversion failed.")
        exit(1)

if __name__ == "__main__":
    main()