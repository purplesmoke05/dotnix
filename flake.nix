{
  # Inputs / 外部依存関係
  # Declare flake inputs for systems and tooling. / システムとツールを支えるフレーク入力を定義。
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-jira.url = "github:NixOS/nixpkgs/6c9a78c09ff4d6c21d0319114873508a6ec01655";
    nixpkgs-logcli.url = "github:NixOS/nixpkgs/6c9a78c09ff4d6c21d0319114873508a6ec01655";
    # Used only to build the pinned opencode package (older nixpkgs lacks models-dev.jsonschema). / opencode のビルド依存用。
    nixpkgs-opencode.url = "github:NixOS/nixpkgs/ef34387ddd751e1ab8857adf4676492d32eb24ec";
    # OfficeCLI uses the patched .NET runtime from this input. / OfficeCLI はこの入力の修正版 .NET を使用。
    nixpkgs-officecli.url = "github:NixOS/nixpkgs/c59305bab2065cfecc4944690d9eedbb56f3a9fa";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    xremap = {
      url = "github:xremap/nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprpanel = {
      url = "github:Jas-SinghFSU/HyprPanel";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Per-monitor workspaces as a Lua package; hyprsplit does not build on Hyprland 0.56 or later. / モニター別ワークスペースを Lua パッケージで提供する。hyprsplit は Hyprland 0.56 以降でビルドできない。
    split-monitor-workspaces = {
      url = "github:zjeffer/split-monitor-workspaces/v0.57.2";
      flake = false;
    };
    hyprland = {
      url = "github:hyprwm/Hyprland/v0.57.2";
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
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Outputs / 出力定義
  # Collect systems, overlays, and Home Manager setups. / システム構成・オーバーレイ・Home Manager を束ねる。
  outputs = { self, nixpkgs, home-manager, rust-overlay, nixos-hardware, xremap, flake-utils, hyprland, hyprpanel, nix-darwin, brew-nix, sops-nix, ... }@inputs:
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
        };
      };

      # Overlays / オーバーレイ
      # Collect custom overlays and external sources. / 独自パッケージや外部オーバーレイをまとめる。
      overlays = {
        common = final: prev:
          let
            withoutSpeechDispatcher = electron: final.runCommand "${electron.name}-no-speechd"
              {
                nativeBuildInputs = [ final.patchelf ];
                version = electron.version;
                passthru = electron.passthru or { };
                meta = electron.meta or { };
                preferLocalBuild = true;
                allowSubstitutes = false;
              }
              ''
                old_libexec="$(readlink -f ${electron}/libexec)"

                mkdir -p "$out"
                for item in ${electron}/*; do
                  name="$(basename "$item")"
                  if [ "$name" != "libexec" ]; then
                    cp -R --no-preserve=ownership,timestamps "$item" "$out/$name"
                  fi
                done
                mkdir -p "$out/libexec"
                cp -R --no-preserve=ownership,timestamps "$old_libexec/electron" "$out/libexec/electron"
                chmod -R u+rwX "$out"

                electron="$out/libexec/electron/electron"
                rpath="$(patchelf --print-rpath "$electron")"
                rpath_without_speechd="$(printf '%s' "$rpath" | tr ':' '\n' | grep -v 'speech-dispatcher' | paste -sd ':' -)"
                patchelf --set-rpath "$rpath_without_speechd" "$electron"

                substituteInPlace "$out/bin/electron" \
                  --replace-fail "${electron}" "$out" \
                  --replace-fail "$old_libexec" "$out/libexec"
              '';

            # Wrap an app's launchers so they drop the capabilities that Hyprland's setcap
            # wrapper raises into the ambient set for every session process. / Hyprland の setcap
            # ラッパーがセッション全プロセスへ ambient capability として継承させている権限を、起動時に落とす。
            # xdg-desktop-portal opens /proc/<pid>/root to classify a caller, and the kernel's
            # ptrace-style check refuses a target that holds capabilities the portal lacks, so it
            # denies file dialogs and other portal requests with AccessDenied. / ポータルは
            # /proc/<pid>/root を開いて呼び出し元を判定するが、自分が持たない capability を持つ
            # 相手は ptrace 相当の検査で拒否されるため、ファイルダイアログ等を AccessDenied で拒否する。
            capDrop =
              bins: drv:
              drv.overrideAttrs (old:
              let
                wrapLaunchers = final.lib.concatMapStrings
                  (bin: ''
                    if [ -L "$out/bin/${bin}" ] || [ -e "$out/bin/${bin}" ]; then
                      mv "$out/bin/${bin}" "$out/bin/.${bin}-capdrop"
                      makeWrapper ${final.lib.getExe' final.util-linux "setpriv"} "$out/bin/${bin}" \
                        --add-flags "--ambient-caps=-all --inh-caps=-all $out/bin/.${bin}-capdrop"
                    fi
                  '')
                  bins;
              in
              {
                nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.makeWrapper ];
              } // (
                # FHS launchers use buildCommand without fixupPhase. / FHS ランチャーは fixupPhase を通らず buildCommand で生成される。
                if old ? buildCommand then {
                  buildCommand = old.buildCommand + wrapLaunchers;
                } else {
                  postFixup = (old.postFixup or "") + wrapLaunchers;
                }
              ));
          in
          {
            # Common overrides / 共通オーバーライド
            # Worktrunk process-table tests are unavailable in the Darwin sandbox. / DarwinのsandboxではWorktrunkのプロセス一覧テストを実行できない。
            worktrunk = prev.worktrunk.overrideAttrs (_: {
              doCheck = !prev.stdenv.hostPlatform.isDarwin;
            });

            # curl and git without the features nothing here uses, to keep runtime closures small. / ランタイム依存を小さくするため、使わない機能を外した curl と git。
            curl_reduced = prev.curl.override {
              gssSupport = false;
              http3Support = false;
              scpSupport = false;
            };

            gitMinimal_curl_reduced = prev.gitMinimal.override {
              curl = final.curl_reduced;
            };

            # OpenSSH patch applied across platforms. / OpenSSH に独自パッチを適用。
            openssh = prev.openssh.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [ ./pkgs/ssh/openssh.patch ];
              doCheck = false;
            });

            # xdg-desktop-portal 1.20.3 USB integration test fails in Nix sandbox
            # (no PipeWire/RealtimeKit). Skip checks to unblock system builds.
            xdg-desktop-portal = prev.xdg-desktop-portal.overrideAttrs (_: {
              doCheck = false;
            });

            # Keep Chrome out of the Speech Dispatcher runtime closure. / Chrome の Speech Dispatcher ランタイム依存を外す。
            google-chrome = prev.google-chrome.override {
              speechd-minimal = final.emptyDirectory;
            };

            # Keep Electron runtimes out of the Speech Dispatcher runtime closure. / Electron ランタイムの Speech Dispatcher 依存を外す。
            electron_39 = withoutSpeechDispatcher prev.electron_39;
            electron_40 = withoutSpeechDispatcher prev.electron_40;
            electron_41 = withoutSpeechDispatcher prev.electron_41;

            # Prefer current FFmpeg for Telegram Desktop and tg_owt. / Telegram Desktop と tg_owt は新しい FFmpeg を優先。
            telegram-desktop = prev.telegram-desktop.override {
              unwrapped = prev.telegram-desktop.unwrapped.override {
                ffmpeg_6 = final.ffmpeg_8;
                tg_owt = prev.telegram-desktop.tg_owt.override {
                  ffmpeg_6 = final.ffmpeg_8;
                };
              };
            };

            # fcitx5 alias / fcitx5 代替
            qt6Packages = prev.qt6Packages.overrideScope (_qtFinal: qtPrev: {
              fcitx5-with-addons = qtPrev.fcitx5-with-addons.override {
                withConfigtool = false;
              };
            });

            libsForQt5 = prev.libsForQt5 // {
              fcitx5-with-addons = final.qt6Packages.fcitx5-with-addons;
            };

            # ghq 1.12.0 has the x/net fixes. Follows nixpkgs once it catches up. / x/net の修正は 1.12.0 から。nixpkgs が追いつけばそちらを使う。
            ghq =
              if final.lib.versionAtLeast prev.ghq.version "1.12.0" then
                prev.ghq
              else
                prev.ghq.overrideAttrs (_: {
                  version = "1.12.0";
                  src = final.fetchFromGitHub {
                    owner = "x-motemen";
                    repo = "ghq";
                    tag = "v1.12.0";
                    hash = "sha256-UrxfWZw9TBQUuTfhp2IVfVxnFvGF1GIRfP87mkND/1Q=";
                  };
                  vendorHash = "sha256-FvMqeUfX4c2Vm+L2GIDGoxN3w+7UyNI0VRada0zSvcc=";
                });

            # claude-code package / claude-code パッケージ
            claude-code = final.callPackage ./pkgs/claude-code { };

            # opencode package (pinned; built with nixpkgs-opencode for newer build deps) / opencode パッケージ
            opencode = (import inputs.nixpkgs-opencode { system = final.stdenv.hostPlatform.system; }).callPackage ./pkgs/opencode { };

            # rtk package / rtk パッケージ
            rtk = final.callPackage ./pkgs/rtk {
              gitMinimal = final.gitMinimal_curl_reduced;
            };

            # Headroom launcher package / Headroom ランチャーパッケージ
            headroom = final.callPackage ./pkgs/headroom { };

            # Pi coding agent package / Pi コーディングエージェントパッケージ
            pi = final.callPackage ./pkgs/pi { };

            # Bladebro agent browser package / Bladebro エージェントブラウザパッケージ
            bladebro = final.callPackage ./pkgs/bladebro { };

            # github-copilot-cli package / github-copilot-cli パッケージ
            github-copilot-cli = final.callPackage ./pkgs/github-copilot-cli { };

            # Hunk terminal diff viewer package / Hunk ターミナル diff ビューアパッケージ
            hunk = final.callPackage ./pkgs/hunk { };

            # Orca agent development environment package / Orca エージェント開発環境パッケージ
            orca-ide = final.callPackage ./pkgs/orca-ide { };

            # Herdr AI agent multiplexer package / Herdr AI エージェントマルチプレクサパッケージ
            herdr = final.callPackage ./pkgs/herdr { };

            # Herdr workflow plugins / Herdr ワークフロープラグイン
            herdr-reviewr-plugin = final.callPackage ./pkgs/herdr-reviewr-plugin { };
            herdr-annotate-plugin = final.callPackage ./pkgs/herdr-annotate-plugin { };
            herdr-auto-title-plugin = final.callPackage ./pkgs/herdr-auto-title-plugin { };
            herdr-memex-plugin = final.callPackage ./pkgs/herdr-memex-plugin { };
            herdr-navigator-plugin = final.callPackage ./pkgs/herdr-navigator-plugin { };
            herdr-agent-usage-plugin = final.callPackage ./pkgs/herdr-agent-usage-plugin { };

            # wtp package / wtp パッケージ
            wtp = final.callPackage ./pkgs/wtp { };

            # confluence-cli package / confluence-cli パッケージ
            confluence-cli = final.callPackage ./pkgs/confluence-cli { };

            # excel-cli package / excel-cli パッケージ
            excel-cli = final.callPackage ./pkgs/excel-cli { };
            # Pinned OfficeCLI with local preview assets. / 描画資産も固定した OfficeCLI。
            # Previews use the system Brave rather than an older one from the pinned officecli nixpkgs. / プレビューには、固定した officecli 用 nixpkgs の古い版ではなくシステムの Brave を使う。
            officecli = (import inputs.nixpkgs-officecli { system = final.stdenv.hostPlatform.system; }).callPackage ./pkgs/officecli {
              inherit (final) brave;
            };
            # m365 package / m365 パッケージ
            m365 = final.callPackage ./pkgs/m365 { };
            # workiq package / workiq パッケージ
            workiq = final.callPackage ./pkgs/workiq { };
            # Python helpers / Python ヘルパー
            inherit (mkPythonBuilders prev) buildPython pythonVersions;

            # Keep Slither on Python 3.13 because py-evm does not support Python 3.14. / py-evm が Python 3.14 非対応のため Slither は Python 3.13 を使用。
            slither-analyzer = final.python313Packages.slither-analyzer;

            # StreamController package override with local patches. / ローカルパッチ適用版 StreamController。
            streamcontroller = capDrop [ "streamcontroller" ] (prev.streamcontroller.overrideAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.perl ];
              postPatch = (old.postPatch or "") + ''
                perl -0pi -e 's|deck_controller = DeckController\(self, deck\)\n\s*self\.deck_controller\.append\(deck_controller\)|try:\n                deck_controller = DeckController(self, deck)\n            except Exception:\n                log.exception("Failed to initialize deck controller. Skipping deck until reconnect.")\n                try:\n                    deck.close()\n                except Exception:\n                    pass\n                try:\n                    self.reset_all_decks()\n                except Exception:\n                    pass\n                continue\n            self.deck_controller.append(deck_controller)|s' src/backend/DeckManagement/DeckManager.py
                perl -0pi -e 's|def add_newly_connected_deck\(self, deck:StreamDeck, is_fake: bool = False\):\n\s*deck_controller = DeckController\(self, deck\)|def add_newly_connected_deck(self, deck:StreamDeck, is_fake: bool = False):\n        try:\n            deck_controller = DeckController(self, deck)\n        except Exception:\n            log.exception("Failed to initialize newly connected deck.")\n            try:\n                deck.close()\n            except Exception:\n                pass\n            try:\n                self.reset_all_decks()\n            except Exception:\n                pass\n            return|s' src/backend/DeckManagement/DeckManager.py
              '';
            }));

            # StreamController OSPlugin patch / StreamController OSPlugin パッチ
            streamcontroller-osplugin-patch = final.callPackage ./pkgs/streamcontroller-osplugin-patch { };

            # Apps whose file dialogs the portal denies until they stop inheriting the session
            # capabilities; see capDrop above. / セッション継承の権限を落とすまで、ポータルに
            # ファイルダイアログを拒否されるアプリ。詳細は上の capDrop を参照。
            brave = capDrop [ "brave" ] (final.callPackage ./pkgs/brave { });
            vesktop = capDrop [ "vesktop" ] prev.vesktop;
            vscode = capDrop [ "code" ] prev.vscode;
            loupe = capDrop [ "loupe" ] prev.loupe;

            # Bubblewrap rejects inherited capabilities before starting Steam. / Bubblewrap は継承した権限を拒否して Steam 起動前に終了する。
            steam = capDrop [ "steam" ] prev.steam;

          };

        nixos = final: prev:
          let
            ironbarGdkPixbuf = (prev.gdk-pixbuf.override {
              libtiff = final.emptyDirectory;
            }).overrideAttrs (oldAttrs: {
              mesonFlags = (oldAttrs.mesonFlags or [ ]) ++ [ "-Dtiff=disabled" ];
              propagatedBuildInputs = final.lib.remove final.emptyDirectory (oldAttrs.propagatedBuildInputs or [ ]);
            });
            ironbarLibrsvg = prev.librsvg.override {
              gdk-pixbuf = ironbarGdkPixbuf;
            };
            ironbarGlibNetworking = prev.glib-networking.override {
              libproxy = prev.libproxy.override {
                curl = final.curl_reduced;
              };
            };
            ironbarGtk4 = (prev.gtk4.override {
              broadwaySupport = false;
              cupsSupport = false;
              gdk-pixbuf = ironbarGdkPixbuf;
              libtiff = final.emptyDirectory;
              trackerSupport = false;
              vulkanSupport = false;
            }).overrideAttrs (oldAttrs: {
              buildInputs = final.lib.remove final.emptyDirectory
                (
                  final.lib.remove prev.gst_all_1.gst-plugins-base (
                    final.lib.remove prev.gst_all_1.gst-plugins-bad (oldAttrs.buildInputs or [ ])
                  )
                ) ++ [ prev.libdrm ];
              mesonFlags = map
                (flag: if flag == "-Dx11-backend=true" then "-Dx11-backend=false" else flag)
                (oldAttrs.mesonFlags or [ ])
              ++ [
                "-Dmedia-gstreamer=disabled"
              ];
              postPatch = (oldAttrs.postPatch or "") + ''
                substituteInPlace meson.build \
                  --replace-fail "tiff_dep          = dependency('libtiff-4', 'tiff')" \
                                 "tiff_dep          = dependency('libtiff-4', 'tiff', required: false)"
                substituteInPlace gdk/meson.build \
                  --replace-fail "  tiff_dep," ""
                substituteInPlace gdk/gdktexture.c \
                  --replace-fail $'  bytes = gdk_save_tiff (texture);\n  result = g_file_set_contents' \
                                 $'  bytes = gdk_save_tiff (texture);\n  if (bytes == NULL)\n    return FALSE;\n  result = g_file_set_contents'
                substituteInPlace gdk/gdkcontentserializer.c \
                  --replace-fail "  input = g_memory_input_stream_new_from_bytes (bytes);" \
                                 $'  if (bytes == NULL)\n    {\n      g_task_return_new_error (task,\n                               GDK_TEXTURE_ERROR,\n                               GDK_TEXTURE_ERROR_UNSUPPORTED_CONTENT,\n                               "TIFF support is disabled");\n      return;\n    }\n\n  input = g_memory_input_stream_new_from_bytes (bytes);'
                cat > gdk/loaders/gdktiff.c <<'EOF'
                #include "config.h"
                #include "gdktiffprivate.h"
                #include <glib/gi18n-lib.h>

                GdkTexture *
                gdk_load_tiff (GBytes  *bytes,
                               GError **error)
                {
                  (void) bytes;
                  if (error != NULL)
                    g_set_error_literal (error,
                                         GDK_TEXTURE_ERROR,
                                         GDK_TEXTURE_ERROR_UNSUPPORTED_CONTENT,
                                         _("TIFF support is disabled"));
                  return NULL;
                }

                GBytes *
                gdk_save_tiff (GdkTexture *texture)
                {
                  (void) texture;
                  return NULL;
                }
                EOF
              '';
            });
            ironbarGtk4LayerShell = prev.gtk4-layer-shell.override {
              gtk4 = ironbarGtk4;
            };
          in
          {
            # NixOS-specific overlays / NixOS 専用オーバーレイ
            ironbar = (prev.ironbar.override {
              features = [
                "battery"
                "bluetooth"
                "cli"
                "clock"
                "config+json"
                "custom"
                "focused"
                "ipc"
                "label"
                "menu"
                "music+mpris"
                "network_manager"
                "notifications"
                "script"
                "tray"
                "volume"
              ];
              gdk-pixbuf = ironbarGdkPixbuf;
              glib-networking = ironbarGlibNetworking;
              gtk4 = ironbarGtk4;
              gtk4-layer-shell = ironbarGtk4LayerShell;
              librsvg = ironbarLibrsvg;
              webp-pixbuf-loader = final.emptyDirectory;
              wrapGAppsHook4 = prev.wrapGAppsHook4.override {
                gtk3 = ironbarGtk4;
                librsvg = ironbarLibrsvg;
              };
            }).overrideAttrs (oldAttrs: {
              # The dropdown selection guard is upstream since 0.19.1 (IgnoreGuard). / ドロップダウン選択の保護は 0.19.1 で上流に入った（IgnoreGuard）。
              patches = (oldAttrs.patches or [ ]) ++ [
                ./pkgs/ironbar/volume-default-sink-wrapper.patch
              ];
              propagatedBuildInputs = [ ];
            });

            obsidian = prev.obsidian.overrideAttrs (oldAttrs: rec {
              installPhase = builtins.replaceStrings
                [ "--ozone-platform=wayland" ]
                [ "--enable-features=UseOzonePlatform --ozone-platform=wayland" ]
                oldAttrs.installPhase;
            });



            # Codex CLI (prebuilt) / Codex CLI（バイナリ）
            codex = final.callPackage ./pkgs/codex { };

            # Hazkey package / Hazkey パッケージ
            fcitx5-hazkey = final.callPackage ./pkgs/fcitx5-hazkey { };

            # fcitx5-mozc that hides the candidate window when there are no candidates (the PR #74 paging fix is upstream now). / 候補がないときに候補ウィンドウを隠す fcitx5-mozc（PR #74 のページ更新修正は取り込み済み）。
            fcitx5-mozc = prev.fcitx5-mozc.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [
                ./pkgs/fcitx5-mozc/hide-candidates-when-absent.patch
              ];
            });

            # fcitx5-gtk GTK4 client-side candidate popup full-size fix. / GTK4 候補ウィンドウの全サイズ表示修正。
            fcitx5-gtk = prev.fcitx5-gtk.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [
                ./pkgs/fcitx5-gtk/gtk4-popup-full-size.patch
              ];
            });

            # wpaperd that frees a removed output's GL objects in that output's own context; 1.3.0 freed them in another output's context, which crashed it in Mesa whenever an output was re-added (every LG PBP switch-off). / 外れた出力の GL オブジェクトをその出力のコンテキストで解放する wpaperd。1.3.0 は別の出力のコンテキストで解放し、出力の付け直し（LG の PBP を切るたび）で Mesa の中で落ちていた。
            wpaperd = prev.wpaperd.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [
                ./pkgs/wpaperd/drop-renderer-in-own-context.patch
              ];
            });

            # hints package (NixOS only) / hints パッケージ（NixOS 限定）
            hints = final.callPackage ./pkgs/hints { };

            # FFmpeg 9.1 until nixpkgs ships it (NixOS/nixpkgs#590840). 9.1 fixes the FFmpeg CVEs published on 2026-11-09 ("FFmpeg through 9.0.2"). It is nixpkgs' own generic.nix with what that PR changes for 9.1: 9.1 already contains the openapv 1.1 fix and drops the OpenGL option. The version reads 9.1.0 so that hq can swap it in for 9.0.2 with replaceDependencies, which needs names of the same length. Remove it once nixpkgs has 9.1. / nixpkgs に入るまでの FFmpeg 9.1（NixOS/nixpkgs#590840）。2026-11-09 に公開された FFmpeg の CVE（「9.0.2 以下」）を直している。nixpkgs の generic.nix に、その PR が 9.1 で変える点（openapv 1.1 の修正は取り込み済み、OpenGL のオプションは廃止）だけを合わせる。版を 9.1.0 と書くのは、hq が replaceDependencies で 9.0.2 と差し替えるときに同じ長さの名前が要るため。nixpkgs が 9.1 になったら外す。
            ffmpeg-headless_9_1 = (final.callPackage "${prev.path}/pkgs/development/libraries/ffmpeg/generic.nix" {
              inherit (final.darwin) xcode;
              inherit (final.cudaPackages) cuda_cudart cuda_nvcc libnpp;
              version = "9.1.0";
              source = final.fetchgit {
                url = "https://git.ffmpeg.org/ffmpeg.git";
                rev = "n9.1";
                hash = "sha256-XK9nk9wqoINbMqjTE6dWm4E5b3wmke4vsqeHshgu6UQ=";
              };
              ffmpegVariant = "headless";
            }).overrideAttrs (old: {
              patches = prev.lib.filter (patch: !(prev.lib.hasInfix "openapv" (patch.name or ""))) (old.patches or [ ]);
              configureFlags = prev.lib.filter (flag: !(prev.lib.hasSuffix "-opengl" flag)) old.configureFlags;
            });

            # FFmpeg for the media that StreamController opens through imageio-ffmpeg and videoprops. It reads GIF, MP4 (H.264) and WebM (VP8/VP9) only, so CVEs in every other decoder, demuxer or filter are not compiled into it, and the vulnerability check sees that per CVE. / StreamController が imageio-ffmpeg と videoprops 経由で開く動画用の FFmpeg。GIF、MP4（H.264）、WebM（VP8/VP9）だけを読むので、ほかのデコーダー・デマルチプレクサー・フィルターの CVE はこのビルドに入っておらず、脆弱性チェックも CVE ごとにそう判定する。
            ffmpeg-streamcontroller = (final.ffmpeg-headless_9_1.override {
              withHeadlessDeps = false;
              buildFfmpeg = true;
              buildFfprobe = true;
              buildAvcodec = true;
              buildAvdevice = true;
              buildAvfilter = true;
              buildAvformat = true;
              buildAvutil = true;
              buildSwresample = true;
              buildSwscale = true;
              withZlib = true;
              withSafeBitstreamReader = true;
            }).overrideAttrs (old: {
              pname = "ffmpeg-streamcontroller";
              # imageio-ffmpeg checks that the binary reports this version, and nothing swaps this build in, so it needs no padded name. The source stays the 9.1 tag, so the version-without-src warning does not apply. / imageio-ffmpeg はバイナリーが報告する版とこの版の一致を確かめる。このビルドは差し替えに使わないので、名前の長さを合わせる必要もない。ソースは 9.1 のタグのままなので、src なしで版を変えたという警告は当たらない。
              version = "9.1";
              __intentionallyOverridingVersion = true;
              configureFlags = old.configureFlags ++ [
                "--disable-everything"
                "--enable-protocol=file,pipe"
                "--enable-demuxer=gif,matroska,mov"
                "--enable-decoder=gif,h264,vp8,vp9"
                "--enable-parser=gif,h264,vp8,vp9"
                "--enable-bsf=vp9_superframe_split"
                # imageio-ffmpeg reads frames as raw video from a pipe. / imageio-ffmpeg はフレームを raw video としてパイプから読む。
                "--enable-encoder=rawvideo"
                "--enable-muxer=image2pipe,rawvideo"
                "--enable-filter=format,null,scale"
              ];
              # FATE would test components this build leaves out. / FATE はこのビルドに入れない部品も試験する。
              doCheck = false;
            });
            # OpenCV without FFmpeg: nixpkgs' OpenCV still needs FFmpeg 8, which the 2026-11-09 FFmpeg CVEs all reach. StreamController reads key and background videos through OpenCV's GStreamer backend instead, and hints only processes screenshots. / FFmpeg なしの OpenCV。nixpkgs の OpenCV はまだ FFmpeg 8 が必要で、2026-11-09 の FFmpeg の CVE がすべて当たる。StreamController のキーと背景の動画は GStreamer バックエンドで読み、hints はスクリーンショットを処理するだけ。
            opencv4 = prev.opencv4.override { enableFfmpeg = false; };

            # nixpkgs ships typepy 2.0 while these typepy users still require typepy<2, which breaks sbomnix (via df-diskcache and SimpleSQLite) for the vulnerability check. / nixpkgs の typepy 2.0 とこれらの typepy<2 指定が衝突し、脆弱性チェックの sbomnix（df-diskcache・SimpleSQLite 経由）がビルドできないため緩める。
            pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
              (_pyFinal: pyPrev:
                let
                  relaxTypepy = pkg: pkg.overridePythonAttrs (old: {
                    pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "typepy" ];
                  });
                in
                {
                  dataproperty = relaxTypepy pyPrev.dataproperty;
                  simplesqlite = relaxTypepy pyPrev.simplesqlite;
                  sqliteschema = relaxTypepy pyPrev.sqliteschema;
                  tabledata = relaxTypepy pyPrev.tabledata;
                })
              # StreamController's other FFmpeg users get the same narrow build as OpenCV. / StreamController のほかの FFmpeg 利用者も OpenCV と同じ絞ったビルドを使う。
              (_pyFinal: pyPrev: {
                imageio-ffmpeg = pyPrev.imageio-ffmpeg.override { ffmpeg = final.ffmpeg-streamcontroller; };
                get-video-properties = pyPrev.get-video-properties.override { ffmpeg-headless = final.ffmpeg-streamcontroller; };
                # imageio's FFmpeg tests write H.264 video, which the narrow build cannot encode. StreamController does not write video with imageio. / imageio の FFmpeg テストは H.264 の動画を書き出すが、絞ったビルドではエンコードできない。StreamController は imageio で動画を書き出さない。
                imageio = pyPrev.imageio.overridePythonAttrs (old: {
                  disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
                    "tests/test_ffmpeg.py"
                    "tests/test_ffmpeg_info.py"
                  ];
                });
              })
            ];

            python312Packages = prev.python312Packages.overrideScope (pyFinal: pyPrev: {
              mss = pyPrev.mss.overridePythonAttrs (_: {
                doCheck = false;
              });
            });

            # StreamController Hyprland wrapper. / StreamController の Hyprland ラッパー。
            streamcontroller-hypr = final.callPackage ./pkgs/streamcontroller-hypr { };

            hyprpanel = prev.hyprpanel;
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
            inherit inputs nixpkgs hostname username;
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
      mkSystem = { system ? "x86_64-linux", hostname, enabledUsers ? [ "primary" ], extraModules ? [ ] }:
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
            sops-nix.nixosModules.sops
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
                assertion = currentUser != "" && currentUser == username;
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
          ] ++ extraModules;
          specialArgs = {
            inherit nixpkgs inputs hostname username;
          };
        };

      darwinUser = let env = builtins.getEnv "DARWIN_USER"; in if env != "" then env else "user"; # Default "user" fallback / 未設定時は "user"
      darwinHost = let env = builtins.getEnv "DARWIN_HOST"; in if env != "" then env else "darwin-host"; # Default "darwin-host" fallback / 未設定時は "darwin-host"

      # Darwin builder / Darwin ビルダー
      mkDarwinSystem = { hostname, username, system ? "aarch64-darwin" }:
        let
          jiraPinnedPkgs = import inputs.nixpkgs-jira {
            inherit system;
            config.allowUnfree = true;
          };
          logcliPinnedPkgs = import inputs.nixpkgs-logcli {
            inherit system;
            config.allowUnfree = true;
          };
        in
        nix-darwin.lib.darwinSystem {
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
              home-manager.extraSpecialArgs = {
                inherit jiraPinnedPkgs;
                inherit logcliPinnedPkgs;
              };
              home-manager.users.${username} = { pkgs, lib, config, ... }: # Provided by HM module / HM から渡される値
                import ./hosts/darwin/home-manager.nix { inherit pkgs lib config username jiraPinnedPkgs logcliPinnedPkgs; }; # Adjusted path and args / パスと引数を調整
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
          ++ [
            pkgs.libpq
            pkgs.pkg-config
            pkgs.playwright-driver.browsers
          ];

          shellHook = ''
            echo "Welcome to Python ${pythonVersion.version} environment"
            export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
            export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
            # Ensure psycopg can resolve libpq at runtime. / psycopg が実行時に libpq を解決できるようにする。
            export PG_CONFIG=${pkgs.libpq}/bin/pg_config
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.libpq ]}:''${LD_LIBRARY_PATH:-}"
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
        };

        packages = pythonTools.pythonVersions // {
          # hints flake output / hints フレーク出力
          hints = pkgs.callPackage ./pkgs/hints { };
          fcitx5-hazkey = pkgs.fcitx5-hazkey;
          claude-code = pkgs.claude-code;
          grype = pkgs.grype;
          sbomnix = pkgs.sbomnix;
          confluence-cli = pkgs.confluence-cli;
          excel-cli = pkgs.excel-cli;
          officecli = pkgs.officecli;
          m365 = pkgs.m365;
          workiq = pkgs.workiq;
          uv = pkgs.uv;
          wtp = pkgs.wtp;
          rtk = pkgs.rtk;
          headroom = pkgs.headroom;
          pi = pkgs.pi;
          hunk = pkgs.hunk;
          opencode = pkgs.opencode;
          herdr = pkgs.herdr;
          herdr-reviewr-plugin = pkgs.herdr-reviewr-plugin;
          herdr-annotate-plugin = pkgs.herdr-annotate-plugin;
          herdr-auto-title-plugin = pkgs.herdr-auto-title-plugin;
          herdr-memex-plugin = pkgs.herdr-memex-plugin;
          herdr-navigator-plugin = pkgs.herdr-navigator-plugin;
          herdr-agent-usage-plugin = pkgs.herdr-agent-usage-plugin;
        } // pkgs.lib.optionalAttrs (pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.bladebro) {
          bladebro = pkgs.bladebro;
        } // pkgs.lib.optionalAttrs (pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.brave) {
          brave = pkgs.brave;
        } // pkgs.lib.optionalAttrs (pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.orca-ide) {
          orca-ide = pkgs.orca-ide;
        };
        formatter = pkgs.nixpkgs-fmt;
      }
    )) // {
      # Export overlays / オーバーレイをエクスポート
      inherit overlays;

      # NixOS configurations / NixOS 構成
      # Define host-specific systems. / ホストごとのシステム定義。
      lib = {
        mkHqSystem = { system ? "x86_64-linux", extraModules ? [ ], enabledUsers ? [ "primary" ] }:
          mkSystem {
            inherit system extraModules enabledUsers;
            hostname = "hq";
          };
      };

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
