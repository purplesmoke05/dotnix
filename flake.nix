{
  # Inputs / 外部依存関係
  # Declare flake inputs for systems and tooling. / システムとツールを支えるフレーク入力を定義。
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    xremap.url = "github:xremap/nix-flake";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    hyprpanel = {
      url = "github:Jas-SinghFSU/HyprPanel";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprsplit = {
      url = "github:shezdy/hyprsplit?ref=v0.52.1";
      inputs.hyprland.follows = "hyprland";
    };
    hyprland = {
      url = "github:hyprwm/Hyprland/v0.52.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser-flake = {
      url = "github:MarceColl/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    brew-nix = {
      url = "github:BatteredBunny/brew-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-darwin.follows = "nix-darwin";
      inputs.brew-api.follows = "brew-api";
    };
    brew-api = {
      url = "github:BatteredBunny/brew-api";
      flake = false;
    };
  };

  # Outputs / 出力定義
  # Collect systems, overlays, and Home Manager setups. / システム構成・オーバーレイ・Home Manager を束ねる。
  outputs = { self, nixpkgs, home-manager, rust-overlay, nixos-hardware, xremap, flake-utils, claude-desktop, mcp-servers-nix, hyprland, hyprsplit, hyprpanel, zen-browser-flake, nix-darwin, brew-nix, ... }@inputs:
    let
      # Python builders / Python ビルダー
      mkPythonBuilders = pkgs: {
        buildPython = { version, sha256 }:
          let
            python = pkgs.python3Packages.python.overrideAttrs (oldAttrs: rec {
              inherit version;
              src = pkgs.fetchurl {
                url = "https://www.python.org/ftp/python/${version}/Python-${version}.tar.xz";
                inherit sha256;
              };
              passthru = oldAttrs.passthru // {
                inherit version;
                pythonVersion = version;
                sourceVersion = version;
                pythonAtLeast = v: builtins.compareVersions version v >= 0;
                pythonOlder = v: builtins.compareVersions version v < 0;
              };
            });
          in
          python;

        # Python versions / Python バージョン一覧
        pythonVersions = let self = mkPythonBuilders pkgs; in {
          py312 = pkgs.python312;
          # Custom 3.12.9 build / 独自 3.12.9 ビルド
          py3129 = self.buildPython {
            version = "3.12.9";
            sha256 = "0w6qyfhc912xxav9x9pifwca40b4l49vy52wai9j0gc1mhni2a5y";
          };
          py311 = pkgs.python311;
          py310 = pkgs.python310;
        };
      };

      # Overlays / オーバーレイ
      # Collect custom overlays and external sources. / 独自パッケージや外部オーバーレイをまとめる。
      overlays = {
        common = final: prev: {
          # Common overrides / 共通オーバーライド
          # OpenSSH patch applied across platforms. / OpenSSH に独自パッチを適用。
          openssh = prev.openssh.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./pkgs/ssh/openssh.patch ];
            doCheck = false;
          });

          # fcitx5 alias / fcitx5 代替
          libsForQt5 = prev.libsForQt5 // {
            fcitx5-with-addons = final.qt6Packages.fcitx5-with-addons;
          };

          # gh-iteration package / gh-iteration パッケージ
          gh-iteration = final.callPackage ./pkgs/gh-iteration { inherit (final) testers; };

          # gemini-cli package / gemini-cli パッケージ
          gemini-cli = final.callPackage ./pkgs/gemini-cli { };

          # uv package / uv パッケージ
          uv = final.callPackage ./pkgs/uv { };

          # ccmanager package / ccmanager パッケージ
          ccmanager-base = final.callPackage ./pkgs/ccmanager { };
          ccmanager = final.callPackage ./pkgs/ccmanager-wrapper {
            ccmanager = final.ccmanager-base;
          };

          # Python helpers / Python ヘルパー
          inherit (mkPythonBuilders prev) buildPython pythonVersions;

          # sui package / sui パッケージ
          sui = final.callPackage ./pkgs/sui { };

          # qSpeak app (deb extraction) / qSpeak アプリ（deb 展開）
          qspeak = final.callPackage ./pkgs/qspeak { };

          # Antigravity IDE / Antigravity IDE
          antigravity = final.callPackage ./pkgs/antigravity {
            vscode-generic = nixpkgs.outPath + "/pkgs/applications/editors/vscode/generic.nix";
          };
        };

        nixos = final: prev: {
          # NixOS-specific overlays / NixOS 専用オーバーレイ
          obsidian = prev.obsidian.overrideAttrs (oldAttrs: rec {
            installPhase = builtins.replaceStrings
              [ "--ozone-platform=wayland" ]
              [ "--enable-features=UseOzonePlatform --ozone-platform=wayland" ]
              oldAttrs.installPhase;
          });



          # Codex CLI (prebuilt) / Codex CLI（バイナリ）
          codex = final.callPackage ./pkgs/codex { };

          # hints package (NixOS only) / hints パッケージ（NixOS 限定）
          hints = final.callPackage ./pkgs/hints {
            python3Packages = final.python312Packages;
          };

          # hyprpanel
          hyprpanel = inputs.hyprpanel.packages.${prev.system}.default;
        };

        # default overlay / default オーバーレイ
        # Combine common and nixos layers for reuse. / common+nixos を束ね再利用性を確保。
        default = final: prev: (self.overlays.common final prev) // (self.overlays.nixos final prev); # Merge common and NixOS layers / 共通+NixOS を結合
      };

      # User Configuration / ユーザー設定
      # Allow host defaults with env overrides. / ホスト別ユーザーを環境変数で上書き可能に。
      systemUsers = {
        laptop = {
          primary = let env = builtins.getEnv "LAPTOP_USER"; in
            if env != "" then env else "thehand";
        };
        hq = {
          primary = let env = builtins.getEnv "HQ_USER"; in
            if env != "" then env else "purplehaze";
        };
      };

      # User template / ユーザーテンプレート
      # Template for shared attributes. / 共通属性の雛形。
      mkUserConfig = { name, description, extraGroups ? [ ], shell ? "fish", ... }: {
        inherit name description extraGroups shell;
        isNormalUser = true;
      };

      # User generation / ユーザー生成
      # Build per-host user definitions. / ホスト別ユーザー定義を生成。
      mkUsers = hostname: {
        primary = mkUserConfig {
          name = systemUsers.${hostname}.primary;
          description = "Yosuke Otosu";
          extraGroups = [ "networkmanager" "wheel" ];
          shell = "fish";
        };
      };

      # Home Manager builder / Home Manager 構築
      mkHomeManagerConfig = { hostname, username }: {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup-hm";
          extraSpecialArgs = {
            inherit inputs nixpkgs hostname username mcp-servers-nix;
            inherit (inputs) hyprsplit;
            userConfig = {
              desktop = true;
              dev = true;
              gaming = true;
            };
          };
          users.${username} = {
            imports = [
              ./hosts/nixos/common/home-manager.nix
              ./hosts/nixos/${hostname}/home-manager.nix
            ];
          };
        };
      };



      # NixOS builder / NixOS ビルダー
      mkSystem = { system ? "x86_64-linux", hostname, enabledUsers ? [ "primary" ] }:
        let
          users = mkUsers hostname;
          username = systemUsers.${hostname}.primary;
          currentUser =
            let
              envUser = builtins.getEnv "USER";
              envSudo = builtins.getEnv "SUDO_USER";
            in
            if envSudo != "" then envSudo
            else if envUser != "" then envUser
            else username;
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/nixos/common/nixos.nix
            home-manager.nixosModules.home-manager
            {
              nixpkgs.overlays = [
                (import rust-overlay)
                self.overlays.default
              ];
            }
            (mkHomeManagerConfig { inherit hostname username; })
            ({ config, pkgs, ... }: {
              assertions = [{
                assertion = builtins.trace "Debug - Checking assertion: currentUser=${currentUser}, username=${username}"
                  (currentUser != "" && currentUser == username);
                message = "Current user (${if currentUser == "" then "unknown" else currentUser}) does not match configured username (${username})";
              }];

              users.users = builtins.listToAttrs (
                builtins.map
                  (userKey: {
                    name = users.${userKey}.name;
                    value = removeAttrs users.${userKey} [ "name" ] // {
                      shell = pkgs.${users.${userKey}.shell};
                    };
                  })
                  enabledUsers
              );
            })
            ./hosts/nixos/${hostname}/nixos.nix
          ];
          specialArgs = {
            inherit nixpkgs inputs hostname username;
            inherit (inputs) hyprsplit;
          };
        };

      darwinUser = let env = builtins.getEnv "DARWIN_USER"; in if env != "" then env else "user"; # Default "user" fallback / 未設定時は "user"
      darwinHost = let env = builtins.getEnv "DARWIN_HOST"; in if env != "" then env else "darwin-host"; # Default "darwin-host" fallback / 未設定時は "darwin-host"

      # Darwin builder / Darwin ビルダー
      mkDarwinSystem = { hostname, username, system ? "aarch64-darwin" }: nix-darwin.lib.darwinSystem {
        inherit system;
        pkgs = import nixpkgs {
          inherit system;
          # Apply overlays and allow unfree / オーバーレイ適用と非自由許可
          config.allowUnfree = true; # Adjust allowUnfreePredicate if needed / 必要なら allowUnfreePredicate を設定
          overlays = [
            self.overlays.common
            brew-nix.overlays.default
          ]; # Darwin uses common + brew-nix only / Darwin は common + brew-nix のみ
        };
        modules = [
          ./hosts/darwin/configuration.nix # Darwin system config / Darwin システム設定
          home-manager.darwinModules.home-manager
          {
            networking.hostName = hostname;
            users.users.${username} = {
              home = "/Users/${username}";
              name = username;
            };
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = false; # Original darwin flow / 既定の darwin フローを踏襲
            home-manager.users.${username} = { pkgs, lib, config, ... }: # Provided by HM module / HM から渡される値
              import ./hosts/darwin/home-manager.nix { inherit pkgs lib config username; }; # Adjusted path and args / パスと引数を調整
            home-manager.backupFileExtension = "backup-hm";
          }
        ];
        specialArgs = {
          inherit inputs nixpkgs home-manager username; # Pass required inputs / 必要な入力を渡す
        };
      };
    in
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
          config.allowUnfree = true;
        };
        pythonTools = mkPythonBuilders pkgs;

        mkRustShell = pkgs.mkShell {
          packages = [
            pkgs.openssl
          ];

          shellHook = ''
            echo "Welcome to Rust development environment"
            if test -e rust-toolchain.toml; then
              echo "rust-toolchain.tomlを検出しました"
              rustup toolchain install $(remarshal -i rust-toolchain.toml -if toml -of json | jq -r .toolchain.channel)
            fi
          '';
        };

        mkSolidityShell = pkgs.mkShell {
          packages = with pkgs; [
            foundry
            solc
            slither-analyzer
          ];

          shellHook = ''
            echo "Welcome to Solidity/Ethereum development environment"
            echo "Available tools:"
            echo "  - forge: Build, test, fuzz, debug and deploy Solidity contracts"
            echo "  - cast: Perform Ethereum RPC calls from the command line"
            echo "  - anvil: Local Ethereum node for development"
            echo "  - chisel: Fast, utilitarian, and verbose Solidity REPL"
            echo "  - solc: Solidity compiler"
            echo "  - slither: Solidity static analyzer"
          '';
        };

        pythonPackages = pythonVersion: with pythonVersion.pkgs; [
          playwright
        ];

        mkPythonShell = pythonVersion: pkgs.mkShell {
          packages = [ pythonVersion ]
          ++ (pythonPackages pythonVersion)
          ++ [ pkgs.playwright-driver.browsers ];

          shellHook = ''
            echo "Welcome to Python ${pythonVersion.version} environment"
            export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
            export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
          '';
        };

      in
      {
        devShells = {
          default = pkgs.mkShell {
            buildInputs = [ pythonTools.pythonVersions.py312 pkgs.fish ];
            shellHook = ''
              echo "Welcome to Python ${pythonTools.pythonVersions.py312.version} environment"
              # Launch fish if current shell differs / 現在のシェルが異なれば fish を起動
              echo "Current shell: $SHELL"
              echo "Current shell: $FISH_VERSION"
              if [ -z "$FISH_VERSION" ]; then
                exec ${pkgs.fish}/bin/fish
              fi
            '';
          };

          rust = mkRustShell;
          solidity = mkSolidityShell;
          py3129 = mkPythonShell pythonTools.pythonVersions.py3129;
          py312 = mkPythonShell pythonTools.pythonVersions.py312;
          py311 = mkPythonShell pythonTools.pythonVersions.py311;
        };

        packages = pythonTools.pythonVersions // {
          # hints flake output / hints フレーク出力
          hints = pkgs.callPackage ./pkgs/hints {
            python3Packages = pkgs.python312Packages;
          };
          uv = pkgs.uv;
        };
        formatter = pkgs.nixpkgs-fmt;
      }
    )) // {
      # Export overlays / オーバーレイをエクスポート
      inherit overlays;

      # NixOS configurations / NixOS 構成
      # Define host-specific systems. / ホストごとのシステム定義。
      nixosConfigurations = {
        laptop = mkSystem {
          hostname = "laptop";
          enabledUsers = [ "primary" ];
        };
        hq = mkSystem {
          hostname = "hq";
          enabledUsers = [ "primary" ];
        };
      };

      # Darwin configurations / Darwin 構成
      # Enabled when DARWIN env vars are provided. / 環境変数が設定された場合に有効。
      darwinConfigurations.${darwinHost} = mkDarwinSystem {
        hostname = darwinHost;
        username = darwinUser;
      };
    };
}
