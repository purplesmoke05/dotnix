# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS and Home Manager configuration repository (dotnix) that manages system configurations across multiple machines using Nix flakes. The repository supports both NixOS (Linux) and experimental Darwin (macOS) configurations.

## Key Commands

### System Configuration

- **Apply system and home-manager configuration**: `sudo nixos-rebuild switch --flake .#<hostname>`
  - Available hostnames: `laptop`, `hq`
  - Example: `sudo nixos-rebuild switch --flake .#laptop`

### Flake Management

- **Check flake configuration**: `nix flake check`
- **Update flake inputs**: `nix flake update`
- **Show flake metadata**: `nix flake metadata`

### Development Shells

- **Default Python shell**: `nix develop`
- **Rust development**: `nix develop .#rust`
- **Python environments**:
  - `nix develop .#py312` (Python 3.12)
  - `nix develop .#py311` (Python 3.11)
  - `nix develop .#py3129` (Python 3.12.9)

### Package Updates

- **Update Cursor editor**: `./pkgs/code-cursor/update.sh`
- **Format Nix files**: `nix fmt`

## Architecture and Structure

### Core Configuration Files

- **`flake.nix`**: Main entry point defining all system configurations, overlays, and development shells
- **`flake.lock`**: Pinned dependencies for reproducible builds

### Directory Structure

#### `/hosts/`

Contains host-specific configurations:

- `/nixos/common/`: Shared NixOS system and home-manager configurations
- `/nixos/<hostname>/`: Host-specific configurations (hardware, system, home-manager)
- `/darwin/`: macOS configuration (experimental)

#### `/home-manager/`

User environment configurations organized by category:

- `/cli/`: Terminal tools, git, shell configurations
- `/development/`: Development tools and language support
- `/gui/`: GUI applications (browsers, editors, games, chat)
- `/wm/`: Window manager configuration (Hyprland)
- `/mcp-servers/`: MCP (Model Context Protocol) server configurations

#### `/pkgs/`

Custom package definitions:

- `/code-cursor/`: Cursor AI editor package with auto-update script
- `/gh-iteration/`: GitHub CLI extension
- Custom kernel packages and SSH patches

### Key Features

1. **Multi-host Configuration**: Separate configurations for `laptop` and `hq` (desktop) with shared common settings
2. **Pure Wayland Environment**: Uses Hyprland window manager without X11 dependencies
3. **Japanese Language Support**: Full IME configuration with fcitx5 and mozc
4. **Development Environments**: Pre-configured shells for Rust and Python development
5. **MCP Integration**: Configured MCP servers for enhanced AI assistant capabilities
6. **Automated Updates**: GitHub Actions workflow for updating packages like Cursor

### Security Considerations

- Environment-specific usernames are set via environment variables (`LAPTOP_USER`, `HQ_USER`, `DARWIN_USER`)
- The system validates that the current user matches the configured username
- API keys and secrets should never be committed to the repository
- Use the designated secrets directory for sensitive configuration

### MCP (Model Context Protocol) Setup for Claude Code

This repository automatically configures MCP for both Cursor and Claude Code:

1. **Global MCP configuration**: MCP settings are automatically placed at:
   - Cursor: `~/.cursor/mcp.json`
   - Claude Code: `~/.claude/config.json`

2. **No manual setup required**: After rebuilding with `nixos-rebuild switch`, MCP servers are immediately available in Claude Code globally

3. **Available MCP servers**: The following servers are enabled by default:
   - Brave Search (requires API key in `~/.config/mcp-secrets/brave.env`)
   - Filesystem (with home directory access)
   - GitHub (requires API key in `~/.config/mcp-secrets/github.env`)
   - Git, Memory, Time, Fetch, Everart, Everything, Sequential-thinking, Playwright

4. **Project-specific settings**: Each project can still have its own `.claude/settings.local.json` for additional configuration or to override global settings
