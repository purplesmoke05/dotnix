# dotnix

My dotfiles for NixOS

## Setup

1. Modify `/etc/nixos/configuration.nix`:
```diff
programs = {
+ git.enable = true;
};
+ nix.settings.experimental-features = ["nix-command" "flakes"];
```

2. Run `sudo nixos-rebuild switch`

3. Clone this repository and move it:
```bash
mkdir -p ~/.nix
git clone https://github.com/purplesmoke05/dotnix.git ~/.nix
cd ~/.nix
```

4. Apply system and home-manager configurations:
```bash
# Apply system configuration
sudo nixos-rebuild switch --flake .#laptop

# Apply home-manager configuration
nix run nixpkgs#home-manager -- switch --flake .#laptop
```

> Available profiles: `laptop`, `hq`
>
> Make sure to replace your `/etc/nixos/hardware-configuration.nix` with the one from this repository's corresponding host directory before running the commands.

5. Reboot

## Directory Structure

```
.
├── flake.nix                # Main flake configuration
├── hosts
│   ├── common              # Common configurations
│   │   ├── home-manager.nix
│   │   └── nixos.nix
│   └── laptop             # Laptop-specific configurations
│       ├── hardware-configuration.nix
│       ├── home-manager.nix
│       └── nixos.nix
├── home-manager
│   ├── cli                # CLI tools configuration
│   │   ├── default.nix
│   │   ├── git
│   │   └── terminal
│   │       ├── alacritty.nix
│   │       └── starship.nix
│   ├── development        # Development tools
│   │   └── default.nix
│   ├── gui               # GUI applications
│   │   ├── chat
│   │   │   └── discord.nix
│   │   ├── default.nix
│   │   ├── editor
│   │   │   ├── init.lua
│   │   │   └── neovim.nix
│   │   └── game
│   └── wm                # Window manager configurations
│       └── hyprland
│           ├── default.nix
│           ├── gtk.nix
│           ├── hyprpanel.nix
│           ├── rofi.nix
│           └── rofi.rasi
└── pkgs                  # Custom packages
    └── nodePackages
        └── exa-mcp-server
            └── default.nix
```

## Features

### Hyprland
- Window manager configuration with custom panel
- Rofi for application launcher
- GTK theme configuration

### Development Environment
- Neovim configuration
- Git setup
- Terminal setup with Alacritty and Starship prompt

### Applications
- Discord
- Various GUI and CLI tools