{ pkgs, ... }:

{
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