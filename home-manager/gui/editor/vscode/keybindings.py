import json
import os
import shutil
import platform
import argparse
import re
from pathlib import Path
from typing import Dict, Any, List, Optional

def get_vscode_keybindings_path() -> Optional[Path]:
    """Get the path to VSCode keybindings.json based on the operating system."""
    home = Path.home()

    if platform.system() == "Windows":
        return home / "AppData/Roaming/Code/User/keybindings.json"
    elif platform.system() == "Darwin":  # macOS
        return home / "Library/Application Support/Code/User/keybindings.json"
    elif platform.system() == "Linux":
        return home / ".config/Code/User/keybindings.json"
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
        """Format Python value as Nix literal (recursively)."""
        if isinstance(value, str):
            return f'"{self._escape_string(value)}"'
        if value is None:
            return '""'
        if isinstance(value, bool):
            return 'true' if value else 'false'
        if isinstance(value, (int, float)):
            return str(value)
        if isinstance(value, list):
            inner = ' '.join(self._format_value(v) for v in value)
            return f'[ {inner} ]'
        if isinstance(value, dict):
            parts: List[str] = []
            for k, v in value.items():
                # Quote keys that are not simple Nix identifiers
                if re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', k):
                    key_repr = k
                else:
                    key_repr = f'"{self._escape_string(k)}"'
                parts.append(f'{key_repr} = {self._format_value(v)};')
            inner = ' '.join(parts)
            return f'{{ {inner} }}'
        # Fallback to JSON (should be rare)
        return json.dumps(value)

    def _format_binding(self, binding: Dict[str, Any], is_last: bool = False) -> str:
        """Format a single keybinding entry."""
        lines = ["    {"]
        preferred_order = ["args", "command", "key", "when"]

        # Emit preferred keys first, then any remaining keys in alphabetical order / 優先キーを先に出し、その後に残りをアルファベット順で出力
        ordered_keys: List[str] = []
        for key in preferred_order:
            if key in binding:
                ordered_keys.append(key)
        for key in sorted(binding.keys()):
            if key not in ordered_keys:
                ordered_keys.append(key)

        for key in ordered_keys:
            value = binding[key]
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
    # Environment override to force skipping
    if os.getenv('UPDATE_SKIP_VSCODE', '').lower() in ('1', 'true', 'yes'):
        print('Skipping VSCode keybindings sync due to UPDATE_SKIP_VSCODE env')
        return
    parser = argparse.ArgumentParser(description='Convert VSCode keybindings to Nix format')
    parser.add_argument('--input', help='Path to VSCode keybindings.json (defaults to platform-specific location).')
    args = parser.parse_args()

    current_dir = os.path.dirname(os.path.abspath(__file__))
    input_file = os.path.join(current_dir, 'vscode-keybindings.json')
    output_file = os.path.join(current_dir, 'keybindings.nix')

    # Get appropriate keybindings source
    keybindings_source = Path(args.input) if args.input else get_vscode_keybindings_path()
    if keybindings_source and keybindings_source.exists():
        try:
            if keybindings_source.resolve() != Path(input_file).resolve():
                shutil.copy2(keybindings_source, input_file)
                os.chmod(input_file, 0o644)
                print(f"Copied keybindings from VSCode: {keybindings_source}")
            else:
                print(f"Using existing keybindings file: {input_file}")
        except Exception as e:
            print(f"Error copying keybindings file: {e}")
            exit(1)
    else:
        if args.input:
            print(f"Specified VSCode keybindings.json not found: {args.input}")
        else:
            print("No VSCode keybindings.json found")
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
