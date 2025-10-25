{ pkgs, ... }:

{
  programs.fish = {
    enable = true;
    shellAliases = {
      dev = "nix develop $HOME/.nix#";
      claude = "claude --dangerously-skip-permissions";
    };
    shellInit = ''
      # VSCode shell integration / VSCode シェル統合
      if test "$TERM_PROGRAM" = "vscode"
          . (code --locate-shell-integration-path fish)
      end

      if string match -q "Darwin" (uname)
        set -gx DARWIN_USER (whoami)
        set -gx DARWIN_HOST (string trim (hostname -s))
        echo "Fish (macOS): DARWIN_USER=$DARWIN_USER, DARWIN_HOST=$DARWIN_HOST"
      end

      # AGENT_MODE auto-detection / AGENT_MODE の自動設定
      if test -n "$npm_config_yes"; or test -n "$CI"; or not status is-interactive
        set -gx AGENT_MODE true
      else
        set -gx AGENT_MODE false
      end

      bind \cr peco_ghq
      bind \cw peco_kill
    '';

    interactiveShellInit =
      # atuin initialization / atuin 初期化
      ''
        atuin init fish --disable-ctrl-r | source
        # Bind Ctrl+J manually / Ctrl+J を手動割当
        bind --erase \cj
        bind \cj _atuin_search
      '';

    # Shell abbreviations / 共通コマンドの短縮形
    shellAbbrs = {
      l = "ls -alh";
      la = "ls -Alh";
      lss = "ls -hsS";
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

      # Docker / Docker 系
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

    # Functions and key bindings / 関数とキーバインド
    functions = {
      # VSCode keybind diff checker / VSCode keybind 差分チェッカー
      __check_vscode_keybind_diff = ''
        function __check_vscode_keybind_diff
          set -l source_type $argv[1]
          set -l temp_file (mktemp)
          set -l current_file (mktemp)
          set -l has_differences 0

          # Get current keybindings from VSCode/Cursor / 現在のキーバインドを取得
          if test "$source_type" = "vscode"
            if command -v code > /dev/null
              code --list-extensions > /dev/null 2>&1
              if test $status -eq 0
                # VSCode is available / VSCode が利用可能
                code --list-extensions | grep -q "vscodevim.vim" > /dev/null 2>&1
                if test $status -eq 0
                  # VSCodeVim extension is installed / VSCodeVim 拡張がインストール済み
                  echo "VSCodeVim extension detected, checking keybind differences..."

                  # Check if keybindings file exists and has content / キーバインドファイルの存在と内容をチェック
                  set -l keybind_file "$HOME/.config/Code/User/keybindings.json"
                  if test -f "$keybind_file"
                    set -l file_size (stat -c%s "$keybind_file" 2>/dev/null || echo "0")
                    if test "$file_size" -gt 2
                      # File has content (more than just "[]") / ファイルに内容がある（"[]"以外）
                      echo "Existing VSCode keybindings found, potential differences detected."
                      set has_differences 1
                    end
                  end

                  # Check if there are any custom keybindings in the Nix config / Nix設定にカスタムキーバインドがあるかチェック
                  if test -f "$HOME/.nix/home-manager/gui/editor/vscode/keybindings.nix"
                    set -l nix_keybind_size (wc -l < "$HOME/.nix/home-manager/gui/editor/vscode/keybindings.nix" 2>/dev/null || echo "0")
                    if test "$nix_keybind_size" -gt 5
                      echo "Nix keybindings configuration found with $nix_keybind_size lines."
                      set has_differences 1
                    end
                  end

                  if test $has_differences -eq 1
                    return 0
                  end
                end
              end
            end
          else if test "$source_type" = "cursor"
            if command -v cursor > /dev/null
              cursor --list-extensions > /dev/null 2>&1
              if test $status -eq 0
                # Cursor is available / Cursor が利用可能
                cursor --list-extensions | grep -q "vscodevim.vim" > /dev/null 2>&1
                if test $status -eq 0
                  # VSCodeVim extension is installed / VSCodeVim 拡張がインストール済み
                  echo "VSCodeVim extension detected in Cursor, checking keybind differences..."

                  # Check if keybindings file exists and has content / キーバインドファイルの存在と内容をチェック
                  set -l keybind_file "$HOME/.config/Cursor/User/keybindings.json"
                  if test -f "$keybind_file"
                    set -l file_size (stat -c%s "$keybind_file" 2>/dev/null || echo "0")
                    if test "$file_size" -gt 2
                      # File has content (more than just "[]") / ファイルに内容がある（"[]"以外）
                      echo "Existing Cursor keybindings found, potential differences detected."
                      set has_differences 1
                    end
                  end

                  # Check if there are any custom keybindings in the Nix config / Nix設定にカスタムキーバインドがあるかチェック
                  if test -f "$HOME/.nix/home-manager/gui/editor/vscode/cursor-keybindings.json"
                    set -l nix_keybind_size (wc -l < "$HOME/.nix/home-manager/gui/editor/vscode/cursor-keybindings.json" 2>/dev/null || echo "0")
                    if test "$nix_keybind_size" -gt 5
                      echo "Nix Cursor keybindings configuration found with $nix_keybind_size lines."
                      set has_differences 1
                    end
                  end

                  if test $has_differences -eq 1
                    return 0
                  end
                end
              end
            end
          end

          # No differences detected / 差分が検出されなかった
          echo "No keybind differences detected, proceeding with update."
          return 1
        end
      '';

      # VSCode keybind update confirmation / VSCode keybind 更新確認
      __confirm_vscode_keybind_update = ''
        function __confirm_vscode_keybind_update
          set -l source_type $argv[1]

          echo ""
          echo "🔧 VSCode keybind update detected / VSCode キーバインドの更新が検出されました"
          echo "Source: $source_type"
          echo ""
          echo "This will update your VSCode keybindings from the Nix configuration."
          echo "既存のVSCodeキーバインドがNix設定で更新されます。"
          echo ""

          while true
            read -l -P "Do you want to proceed with the keybind update? [y/N]: " confirm
            switch $confirm
              case Y y yes Yes YES
                echo "Proceeding with keybind update... / キーバインド更新を実行します..."
                return 0
              case \'\' N n no No NO
                echo "Skipping keybind update. / キーバインド更新をスキップします。"
                return 1
              case '*'
                echo "Please answer 'y' for yes or 'n' for no. / 'y'（はい）または'n'（いいえ）で回答してください。"
            end
          end
        end
      '';

      update = ''
        # Robust flag parsing / argparse 互換の堅牢な解析
        set -l skip_vscode 0

        if type -q argparse
          if not argparse --name=update 'skip-vscode' 'no-vscode' 'h/help' -- $argv
            echo "Usage: update [--skip-vscode|--no-vscode]"
            echo "  --skip-vscode/--no-vscode  Skip syncing VSCode settings/keybindings"
            return 1
          end
          if set -q _flag_help
            echo "Usage: update [--skip-vscode|--no-vscode]"
            echo "  --skip-vscode/--no-vscode  Skip syncing VSCode settings/keybindings"
            return 0
          end
          if set -q _flag_skip_vscode; or set -q _flag_no_vscode
            set skip_vscode 1
          end
        else
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
        end

        # CI override via UPDATE_SKIP_VSCODE=1 / CI では UPDATE_SKIP_VSCODE=1 で上書き
        if test -n "$UPDATE_SKIP_VSCODE"
          set skip_vscode 1
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

            # Check for keybind differences and confirm update / キーバインド差分をチェックして更新を確認
            if __check_vscode_keybind_diff vscode
              if not __confirm_vscode_keybind_update vscode
                echo "Skipping VSCode keybindings update as requested. / 要求に応じてVSCodeキーバインド更新をスキップします。"
              else
                if not uv run python $HOME/.nix/home-manager/gui/editor/vscode/keybindings.py --source vscode
                  echo "Error: Failed to update VSCode keybindings. Aborting."
                  return 1
                end
                echo "VSCode keybindings updated successfully. / VSCodeキーバインドが正常に更新されました。"
              end
            else
              # No keybind differences detected, proceed with update / キーバインド差分が検出されない場合、更新を実行
              if not uv run python $HOME/.nix/home-manager/gui/editor/vscode/keybindings.py --source vscode
                echo "Error: Failed to update VSCode keybindings. Aborting."
                return 1
              end
              echo "VSCode keybindings updated successfully. / VSCodeキーバインドが正常に更新されました。"
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

            # Check for keybind differences and confirm update / キーバインド差分をチェックして更新を確認
            if __check_vscode_keybind_diff cursor
              if not __confirm_vscode_keybind_update cursor
                echo "Skipping VSCode keybindings update as requested. / 要求に応じてVSCodeキーバインド更新をスキップします。"
              else
                if not uv run python $HOME/.nix/home-manager/gui/editor/vscode/keybindings.py --source cursor
                  echo "Error: Failed to update VSCode keybindings. Aborting."
                  return 1
                end
                echo "VSCode keybindings updated successfully. / VSCodeキーバインドが正常に更新されました。"
              end
            else
              # No keybind differences detected, proceed with update / キーバインド差分が検出されない場合、更新を実行
              if not uv run python $HOME/.nix/home-manager/gui/editor/vscode/keybindings.py --source cursor
                echo "Error: Failed to update VSCode keybindings. Aborting."
                return 1
              end
              echo "VSCode keybindings updated successfully. / VSCodeキーバインドが正常に更新されました。"
            end

            echo "VSCode configuration updated successfully."
          else
            echo "Skipping VSCode settings/keybindings sync (--skip-vscode)."
          end

          # Determine target host / NixOS の対象ホスト判定
          set -l target_host
          if test -n "$NIXOS_HOSTNAME"
            set target_host $NIXOS_HOSTNAME
          else
            set target_host (string trim (hostname -s))
          end

          # Lightweight guard / フル評価の代わりにディレクトリ存在を確認
          if not test -f "$HOME/.nix/hosts/nixos/$target_host/nixos.nix"
            echo "Error: target host '$target_host' is not defined (hosts/nixos/$target_host/nixos.nix not found)."
            echo "Hint: set NIXOS_HOSTNAME=<host> to override detection."
            return 1
          end

          echo "Running nixos-rebuild for host: $target_host"
          sudo -E nixos-rebuild switch --flake "$HOME/.nix#$target_host"
        end
      '';

      # Python auto switch / Python バージョン自動切替
      __check_python_version = ''
        if test -e .python-version
          set -l arch (uname -m)
          set -l kernel (uname -s)
          set -l current_system ""

          if test "$kernel" = "Linux"
            if test "$arch" = "x86_64"
              set current_system "x86_64-linux"
            end
          else if test "$kernel" = "Darwin" # macOS / macOS
            if test "$arch" = "arm64" # Apple Silicon (M1, M2) / Apple シリコン
              set current_system "aarch64-darwin"
            else if test "$arch" = "x86_64" # Intel Mac / Intel Mac
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

      # Directory change handler / ディレクトリ変更ハンドラ
      __on_pwd_change = ''
        # Call __check_python_version if available / __check_python_version が定義されている場合に呼ぶ
        functions -q __check_python_version; and __check_python_version
      '';

      # Git add/commit/push / Git add/commit/push を一括
      gish = ''
        git add -A
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

      # Feature branch helper / フィーチャーブランチ作成
      girk = ''
        git checkout develop
        git pull origin develop
        read -l -P "Input feature branch name: " branch_name
        git checkout -b $branch_name
      '';

      # VSCode checks / VSCode 起動確認
      __check_vscode_and_develop = ''
        if test "$TERM_PROGRAM" = "vscode"
          and not test -n "$IN_NIX_SHELL"
          echo "VSCode detected, activating development environment..."
          nix develop $HOME/.nix#
        end
      '';

      # peco_ghq / peco_ghq 関数
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

      # peco_kill / peco_kill 関数
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

      # color_print / カラー出力関数
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
