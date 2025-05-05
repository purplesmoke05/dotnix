{ config, pkgs, ... }:

{
  # User Packages
  # Core user-level packages and tools
  # - Input Method: Complete Fcitx5 + Mozc setup for Japanese
  # - Theme Integration: Icon themes and GUI toolkits
  # - Configuration Tools: Input method setup utilities
  # - Exa MCP Server Package
  home.packages = with pkgs; [
    papirus-icon-theme
    mozc
    fcitx5-mozc
    fcitx5-gtk
    libsForQt5.fcitx5-qt
    qt6Packages.fcitx5-qt
    fcitx5-configtool
    appimage-run
    awscli2
  ];

  # Environment Variables
  # Input method integration across different toolkits
  # - X11/Wayland compatibility
  # - Qt/GTK framework integration
  # - Game engine (SDL/GLFW) support
  home.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    NIXOS_OZONE_WL = "1";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";
    FCITX_ADDON_DIRS = "${pkgs.fcitx5-with-addons}/lib/fcitx5:${pkgs.fcitx5-mozc}/lib/fcitx5";
    DISABLE_KWALLET = "1";
    FCITX_LOG_LEVEL = "debug";
    QT_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
  };

  # Cursor Theme
  # System-wide cursor appearance configuration
  # - Adwaita theme for consistency
  # - GTK integration enabled
  home.pointerCursor = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
    x11 = {
      enable = true;
      defaultCursor = "Adwaita";
    };
    gtk.enable = true;
  };

  # Input Method Configuration Files
  # Detailed Fcitx5 and Mozc configuration
  xdg.configFile = {
    # Input Method Profile
    # Default input method and keyboard layout settings
    "fcitx5/profile" = {
      force = true;
      text = ''
        [Groups/0]
        # Group Name
        Name=Default
        # Layout
        Default Layout=jp
        # Default Input Method
        DefaultIM=mozc

        [Groups/0/Items/0]
        # Name
        Name=mozc
        # Layout
        Layout=jp

        [GroupOrder]
        0=Default
      '';
    };

    # Fcitx5 Global Configuration
    # System-wide input method behavior settings
    "fcitx5/config" = {
      force = true;
      text = ''
        [Hotkey]
        EnumerateKeys=
        TriggerKeys=

        [Behavior]
        DefaultInputMethod=mozc
        ShareInputState=All
      '';
    };

    # Classic UI Configuration
    # Visual appearance and behavior settings
    "fcitx5/conf/classicui.conf" = {
      text = ''
        Vertical Candidate List=False
        PerScreenDPI=True
        WheelForPaging=True
        Font="Noto Sans CJK JP 10"
        Theme=default
      '';
    };

    # Mozc Key Bindings
    # Custom key mappings for IME control
    # - Henkan key: Enable IME
    # - Muhenkan key: Disable IME
    "mozc/keymap.tsv" = {
      force = true;
      text = ''
        status	key	command
        DirectInput	Henkan	IMEOn
        Composition	Henkan	IMEOn
        Conversion	Henkan	IMEOn
        Precomposition	Henkan	IMEOn
        DirectInput	Muhenkan	IMEOff
        Composition	Muhenkan	IMEOff
        Conversion	Muhenkan	IMEOff
        Precomposition	Muhenkan	IMEOff
      '';
    };

    # XIM Configuration
    # Legacy application support settings
    "fcitx5/conf/xim.conf" = {
      force = true;
      text = ''
        UseOnTheSpot=True
      '';
    };

    # Mozc Database
    # Pre-configured Mozc settings database
    "mozc/config1.db" = {
      force = true;
      source = ./mozc/config1.db;
    };

    # Mozc Input Method Configuration
    # Detailed Mozc behavior settings
    "fcitx5/conf/mozc.conf" = {
      force = true;
      text = ''
        InitialMode=Direct
        InputState="Follow Global Configuration"
        Vertical=True
        ExpandMode="On Focus"
        PreeditCursorPositionAtBeginning=False
        ExpandKey=Control+Alt+H
      '';
    };
  };

  # Qt Framework Configuration
  # Qt application theming and integration
  # - GTK theme compatibility
  # - Dark theme preference
  qt = {
    enable = true;
    platformTheme = {
      name = "gtk";
    };
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };

  # Exa MCP Server Service
  # Systemd user service configuration for Exa MCP server
  # - Automatic startup after network
  # - Development API key configuration
  # - Automatic restart on failure

  programs.ssh = {
    enable = true;

    extraConfig = ''
      AddKeysToAgent yes
      ServerAliveInterval 60
    '';

  };

  programs.fish = {
    enable = true;
    shellAliases = {
      dev = "nix develop $HOME/.nix#";
      update = "uv run python $HOME/.nix/home-manager/gui/editor/vscode/settings.py && uv run python $HOME/.nix/home-manager/gui/editor/vscode/keybindings.py && sudo -E nixos-rebuild switch --flake .#hq";
    };
    shellInit = ''
      # Activate VSCode shell integration
      if test "$TERM_PROGRAM" = "vscode"
          . (code --locate-shell-integration-path fish)
      end

      # Directory change handler registration
      # The function __on_pwd_change is defined in the functions block below
      functions -q __on_pwd_change && __on_pwd_change --on-variable PWD

      # Execute initialization checks
      # The function __check_vscode_and_develop is defined in the functions block below
      functions -q __check_vscode_and_develop && __check_vscode_and_develop

      bind \cr peco_ghq
      bind \cw peco_kill
    '';

    interactiveShellInit =
      # Initialize atuin for fish, disabling default Ctrl+R binding
      # Use `atuin init fish --help` to see available flags
      ''
        atuin init fish --disable-ctrl-r | source
        # Manually bind Ctrl+J to atuin search after init
        bind --erase \cj
        bind \cj _atuin_search
      '';

    # Define functions and key bindings here
    functions = {
      # Python version auto-switcher function
      __check_python_version = ''
        if test -e .python-version
          set -l py_version (cat .python-version | string trim)
          set -l version_dots (string join "" (string split "." $py_version))

          if not test -n "$IN_NIX_SHELL"
            set -l dev_shell "py$version_dots"

            if nix flake show $HOME/.nix --json | jq -e ".devShells.\\"x86_64-linux\\".$dev_shell" > /dev/null
              echo "Python $py_version環境を有効化します..."
              nix develop $HOME/.nix#$dev_shell
            else
              echo "警告: サポートされていないPythonバージョン: $py_version"
              echo "デフォルトの3.12を使用します"
            end
          end
        end
      '';

      # Directory change handler function
      __on_pwd_change = ''
        # This function requires __check_python_version to be defined
        functions -q __check_python_version && __check_python_version
      '';

      # Git add, commit, and push function
      gish = ''
          # Stage all changes
          git add -A
          # Show status
          git status

          read -l -P "Commit with this content. OK? (y/N): " confirm
          switch $confirm
              case y Y yes Yes YES
                  read -l -P "Input Commit Message: " msg
                  git commit -m "$msg"
                  set -l current_branch (git rev-parse --abbrev-ref HEAD)
                  git push origin $current_branch --force
              case '*'
                  echo "Quit."
          end
      '';

      # Create new feature branch from develop
      girk = ''
          # Switch to develop branch
          git checkout develop
          # Pull latest changes
          git pull origin develop
          # Create and switch to new feature branch
          read -l -P "Input feature branch name: " branch_name
          git checkout -b $branch_name
      '';

      # Function to check VSCode and activate development environment
      __check_vscode_and_develop = ''
        if test "$TERM_PROGRAM" = "vscode"
          and not test -n "$IN_NIX_SHELL"
          echo "VSCode detected, activating development environment..."
          nix develop $HOME/.nix#
        end
      '';

      # Define the peco_ghq function
      peco_ghq = ''
        set -l query (commandline)

        if test -n $query
            set peco_flags --query "$query"
        end

        ghq list --full-path | peco $peco_flags | read recent
        if [ $recent ]
            cd $recent
            commandline -r ""
            commandline -f repaint
        end
      '';

      # Define the peco_kill function
      peco_kill = ''
        set -e proc
        set -l query (commandline)

        if test -n $query
            ps aux | peco --query "$query" | read proc
        else
            ps aux | peco | read proc
        end
        if test -n "$proc"
            set -l pid (echo $proc | awk '{print $2}')
            echo "kill pid: $pid. [$proc]"
            kill $pid
        end
        set -e proc
      '';
    };
  };
}
