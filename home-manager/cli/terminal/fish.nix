{ pkgs, ... }:

{
  programs.fish = {
    enable = true;
    shellAliases = {
      dev = "nix develop $HOME/.nix#";
      claude = "claude --dangerously-skip-permissions";
    };
    shellInit = ''
      # Activate VSCode shell integration
      if test "$TERM_PROGRAM" = "vscode"
          . (code --locate-shell-integration-path fish)
      end

      if string match -q "Darwin" (uname)
        set -gx DARWIN_USER (whoami)
        set -gx DARWIN_HOST (string trim (hostname -s))
        echo "Fish (macOS): DARWIN_USER=$DARWIN_USER, DARWIN_HOST=$DARWIN_HOST"
      end

      # Set AGENT_MODE based on environment and interactivity
      if test -n "$npm_config_yes"; or test -n "$CI"; or not status is-interactive
        set -gx AGENT_MODE true
      else
        set -gx AGENT_MODE false
      end

      # Directory change handler registration
      # The function __on_pwd_change is defined in the functions block below
      # functions -q __on_pwd_change && __on_pwd_change --on-variable PWD

      # Execute initialization checks
      # The function __check_vscode_and_develop is defined in the functions block below
      # functions -q __check_vscode_and_develop && __check_vscode_and_develop

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

    # Define aliases for common commands
    shellAbbrs = {
      l = "ls -alh";
      la = "ls -Alh";
      lss = "ls -hsS";
      # ls = "ls -alFth --color auto";
      ld = "du -hs */";
      ".." = "cd ..";
      "1" = "cd -";
      "2" = "cd -2";
      "3" = "cd -3";
      "4" = "cd -4";
      "..." = "cd ...";
      "...." = "cd ....";
      "....." = "cd .....";
      ports = "netstat -tulanp";
      reboot = "sudo /sbin/reboot";
      halt = "sudo /sbin/halt";
      httpdreload = "sudo /usr/sbin/apachectl -k graceful";
      httpdtest = "sudo /usr/sbin/apachectl -t && /usr/sbin/apachectl -t -D DUMP_VHOSTS";
      meminfo = "free -m -l -t";
      psmem = "ps auxf | sort -nr -k 4";
      psmem10 = "ps auxf | sort -nr -k 4 | head -10";
      pscpu = "ps auxf | sort -nr -k 3";
      pscpu10 = "ps auxf | sort -nr -k 3 | head -10";

      # Docker
      dcl = "docker container ls -a";
      dc = "docker container";
      dcr = "docker container rm";
      dcs = "docker container stop";
      dcx = "docker container rm";
      dl = "docker container ps -l -q";
      dps = "docker container ps";
      dpa = "docker container ps -a";
      dls = "docker container ps -a";
      di = "docker images";
      dip = "docker container inspect --format '{{ .NetworkSettings.IPAddress }}'";
      dkd = "docker container run -d -P";
      dki = "docker container run -i -t -P";
      dex = "docker container exec -i -t";
      drmf = "docker container stop (docker container ps -a -q); docker container rm (docker container ps -a -q)";
      drmv = "docker volume rm (docker volume ls -qf \"dangling=true\")";
      drmd = "docker rmi (docker container images -q)";
      drxc = "docker container ps --filter status=dead --filter status=exited -aq | xargs docker container rm -v";
      drui = "docker images --no-trunc | grep '<none>' | awk '{ print $3 }' | xargs docker container rmi";
      dprune = "docker container system prune -a";
    };

    # Define functions and key bindings here
    functions = {
      update = ''
        # Parse flags
        set -l skip_vscode 0
        for arg in $argv
          switch $arg
            case '--skip-vscode' '--no-vscode'
              set skip_vscode 1
            case '--help' '-h'
              echo "Usage: update [--skip-vscode|--no-vscode]"
              echo "  --skip-vscode/--no-vscode  Skip syncing VSCode settings/keybindings"
              return 0
          end
        end

        if string match -q "Darwin" (uname)
          echo "Detected macOS."
          if test -z "$DARWIN_HOST"
            echo "Error: DARWIN_HOST environment variable is not set."
            echo "Please ensure 'hostname -s' works and shellInit is correctly setting it for macOS."
            return 1
          end

          if test $skip_vscode -ne 1
            echo "Updating VSCode settings and keybindings from VSCode configuration..."
            if not uv run python $HOME/.nix/home-manager/gui/editor/vscode/settings.py --source vscode
              echo "Error: Failed to update VSCode settings. Aborting."
              return 1
            end
            if not uv run python $HOME/.nix/home-manager/gui/editor/vscode/keybindings.py --source vscode
              echo "Error: Failed to update VSCode keybindings. Aborting."
              return 1
            end
            echo "VSCode configuration updated successfully."
          else
            echo "Skipping VSCode settings/keybindings sync (--skip-vscode)."
          end

          echo "Running darwin-rebuild for host: $DARWIN_HOST using flake at $HOME/.nix"
          sudo -E darwin-rebuild switch --flake "$HOME/.nix#$DARWIN_HOST" --impure
        else
          echo "Detected non-macOS (assuming NixOS/Linux)."

          if test $skip_vscode -ne 1
            echo "Updating VSCode settings and keybindings from Cursor configuration..."
            if not uv run python $HOME/.nix/home-manager/gui/editor/vscode/settings.py --source cursor
              echo "Error: Failed to update VSCode settings. Aborting."
              return 1
            end
            if not uv run python $HOME/.nix/home-manager/gui/editor/vscode/keybindings.py --source cursor
              echo "Error: Failed to update VSCode keybindings. Aborting."
              return 1
            end
            echo "VSCode configuration updated successfully."
          else
            echo "Skipping VSCode settings/keybindings sync (--skip-vscode)."
          end

          # Determine target host for NixOS
          set -l target_host
          if test -n "$NIXOS_HOSTNAME"
            set target_host $NIXOS_HOSTNAME
          else
            set target_host (string trim (hostname -s))
          end

          # Lightweight guard: check host directory presence instead of full Nix evaluation
          if not test -f "$HOME/.nix/hosts/nixos/$target_host/nixos.nix"
            echo "Error: target host '$target_host' is not defined (hosts/nixos/$target_host/nixos.nix not found)."
            echo "Hint: set NIXOS_HOSTNAME=<host> to override detection."
            return 1
          end

          echo "Running nixos-rebuild for host: $target_host"
          sudo -E nixos-rebuild switch --flake "$HOME/.nix#$target_host"
        end
      '';

      # Python version auto-switcher function
      __check_python_version = ''
        if test -e .python-version
          set -l arch (uname -m)
          set -l kernel (uname -s)
          set -l current_system ""

          if test "$kernel" = "Linux"
            if test "$arch" = "x86_64"
              set current_system "x86_64-linux"
            # else if test "$arch" = "aarch64"
            #   set current_system "aarch64-linux"
            end
          else if test "$kernel" = "Darwin" # macOS
            if test "$arch" = "arm64" # Apple Silicon (M1, M2, etc.)
              set current_system "aarch64-darwin"
            else if test "$arch" = "x86_64" # Intel Mac
              set current_system "x86_64-darwin"
            end
          end

          set -l py_version (cat .python-version | string trim)
          set -l version_dots (string join "" (string split "." $py_version))

          if not test -n "$IN_NIX_SHELL"
            set -l dev_shell "py$version_dots"

            if nix flake show $HOME/.nix --json | jq -e ".devShells[\"$current_system\"][\"$dev_shell\"]" > /dev/null
              echo "Python $py_version 環境を有効化します..."
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
        # functions -q __check_python_version && __check_python_version
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

      dstoprm = ''
        docker container stop "$argv[1]" && docker container rm "$argv[1]"
      '';

      dstop = ''
        color_print $COLOR_B "Docker: Stop all containers\n"
        if read_confirm
          set ARG (docker container ps -a -q)
          if test -n "$ARG"
            docker container stop $ARG
          else
            color_print $COLOR_Y "Docker: Nothing to execute."
          end
        end
        disown
      '';

      drm = ''
        color_print $COLOR_B "Docker: Remove all containers\n"
        if read_confirm
          set ARG (docker container ps -a -q)
          if test -n "$ARG"
            docker container rm $ARG
          else
            color_print $COLOR_Y "Docker: Nothing to execute."
          end
        end
      '';

      dri = ''
        color_print $COLOR_B "Docker: Remove all images\n"
        if read_confirm
          set ARG (docker container images -q)
          if test -n "$ARG"
            docker container rmi $ARG
          else
            color_print $COLOR_Y "Docker: Nothing to execute."
          end
        end
      '';

      dbu = ''
        color_print $COLOR_B "Docker: Dockerfile build\n"
        docker build -t=$argv[1] .
      '';

      dalias = ''
        color_print $COLOR_B "Docker: Show all abbreviations related to docker.\n"
        abbr | grep 'docker container' | sed "s/^\([^=]*\)=\(.*\)/\1 => \2/"| sed "s/['|\']//g" | sort
      '';

      dbash = ''
        color_print $COLOR_B "Docker: Bash into running container.\n"
        docker container exec -it (docker container ps -aqf "name=$argv[1]") bash
      '';

      # color_print function
      color_print = ''
        function color_print
          printf "%b" "$argv[1]\e0$argv[2]$COLOR_RESET"
        end
      '';

      read_confirm = ''
        function read_confirm
          while true
            read -l -P 'Do you want to continue? [y/N] ' confirm

            switch $confirm
              case Y y
                return 0
              case \'\' N n
                return 1
            end
          end
        end
      '';
    };
  };
}
