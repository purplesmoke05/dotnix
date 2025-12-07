# dotnix

Dotfiles and Nix flakes for reproducible desktops. / 再現性あるデスクトップ環境を構成するためのドットファイルと Nix フレーク。

## Overview / 概要

- Manage NixOS, experimental nix-darwin, and Home Manager environments from one flake. / 1つのフレークで NixOS・実験的 nix-darwin・Home Manager 環境を統合管理。
- Provide curated overlays, custom packages, and task guides for day-to-day maintenance. / 日常運用のためのオーバーレイ・独自パッケージ・タスクガイドを提供。
- Optimise Hyprland-based desktop workflow with GUI/CLI integrations and MCP tooling. / Hyprland を中心としたデスクトップを GUI/CLI 連携や MCP ツールで最適化。

## Requirements / 前提条件

- NixOS 23.11 以降。（nix-darwin を用いる場合は macOS 14 以降を推奨。）
- `git`、`nixos-rebuild`、`nix` が利用可能であること。
- `/etc/nix/nix.conf` または `nix.settings.experimental-features` で `nix-command` と `flakes` を有効化済み。未設定の場合は下記のセットアップ中に追加してください。
- 既存ホストの `hardware-configuration.nix` を適切に同期していること（ホストごとのディレクトリを参照）。

## Quick Start / クイックスタート

1. システムに Git と Nix flakes を有効化します。

   ```nix
   # /etc/nixos/configuration.nix の例
   programs.git.enable = true;
   nix.settings.experimental-features = [ "nix-command" "flakes" ];
   ```

2. `sudo nixos-rebuild switch` で設定を適用。
3. リポジトリをクローンし、ワークディレクトリを `~/.nix` に設定。

   ```bash
   mkdir -p ~/.nix
   git clone https://github.com/purplesmoke05/dotnix.git ~/.nix
   cd ~/.nix
   ```

4. 対象ホストの `/etc/nixos/hardware-configuration.nix` をリポジトリ内の対応するホストの `hardware-configuration.nix` にコピーまたはマージ。
5. ホスト向けの system + Home Manager を適用。

   ```bash
   sudo nixos-rebuild switch --flake .#laptop
   # 他ホスト: sudo nixos-rebuild switch --flake .#hq
   ```

6. 再起動して設定を反映。

> macOS（実験的）では `nix run .#darwinConfigurations.<host>.system` を参照。/ macOS (experimental) users can review `hosts/darwin/README.md` for additional steps.

## Host Matrix / ホスト一覧

| Host | Platform | Notes |
|------|----------|-------|
| `laptop` | NixOS | モバイル向け設定。Hyprland + Home Manager 標準構成。
| `hq` | NixOS | 据え置きワークステーション。拡張 GUI/開発ツールを有効化。
| `darwin` | macOS (experimental) | `nix-darwin` + Home Manager 統合。要 `brew` 連携。

## Repository Layout / ディレクトリ構成

```
.
├── flake.nix               # Flake entrypoint / フレーク入口
├── flake.lock              # Pin for inputs / 依存固定
├── hosts                   # System definitions / システム定義
│   ├── nixos
│   │   ├── common          # 共通モジュール
│   │   ├── laptop          # Laptop 向け
│   │   └── hq              # HQ 向け
│   └── darwin              # Experimental macOS
├── home-manager            # HM モジュール
│   ├── cli
│   ├── gui
│   ├── development
│   ├── mcp-servers
│   └── wm
├── pkgs                    # Custom packages / 独自パッケージ
│   ├── ccmanager
│   ├── codex
│   ├── gh-iteration
│   ├── ssh
│   ├── sui
│   └── whisper-typing
├── tasks                   # Maintainer workflows / 運用ワークフロー
├── scripts                 # Utility scripts (現在は空) / ユーティリティスクリプト（空）
├── logs                    # ログ収集（例: hotspot_debug）
└── AGENTS.md, README.md, Dockerfile, etc.
```

## Features / 主な機能

- **Hyprland desktop.** Custom Hyprpanel, Rofi, GTK theming, fcitx5 Mozc, Xremap integration. / Hyprpanel や Rofi、GTK テーマ、fcitx5 Mozc、Xremap を組み合わせた Hyprland デスクトップ。
- **Development shells.** `nix develop`, `.#rust`, `.#py312` など Python/Rust ビルダーを提供。/ Rust・Python 向け開発シェルを `nix develop` で提供。
- **Custom overlays.** Patched OpenSSH、`zen-browser`, `claude-code`, `ccmanager` などをオーバーレイ化。/ OpenSSH パッチや独自パッケージをオーバーレイで管理。
- **MCP & automation.** `home-manager/mcp-servers` と `tasks/` が Claude/Codex ワークフローを支援。/ MCP サーバー設定とタスク雛形でエージェント運用を補助。

## Daily Commands / よく使うコマンド

- `nix develop [.<shell>]` — 開発シェルに入る。
- `nix fmt` — Nix ファイルを整形。
- `nix flake check` — 出力と評価を検証。
- `nixos-rebuild build --flake .#<host>` — ドライラン。
- `sudo nixos-rebuild switch --flake .#<host>` — システム適用。
- `nix flake update` — 依存更新。

## Secrets & Security / シークレットとセキュリティ

- シークレットは Git に含めず、`~/.config/mcp-secrets/`（ユーザー向け）や `/var/lib/<service>/`（サービス向け）に配置。/ Never commit secrets; store user secrets under `~/.config/mcp-secrets/` and service secrets under `/var/lib/<service>/`.
- Host guard: `LAPTOP_USER`/`HQ_USER`/`DARWIN_USER` でユーザー名を上書き可能、クロスホスト評価時は `DISABLE_HOST_GUARD=1`。/ Override guard vars when evaluating for different hosts.
- 追加の sops-nix/agenix 等も歓迎。/ Consider adopting sops-nix or agenix for encryption.

## Contribution Workflow / コントリビュート手順

- ブランチ作成前に `nix fmt`・`nix flake check` を実行。
- Conventional Commits + 絵文字プリフィックス（例: `✨ feat:`）。
- 変更点・理由・影響ホストを PR に記載。必要ならスクリーンショット添付。
- UI/WM 変更は `nixos-rebuild build` で検証し、結果を共有。

## Troubleshooting / トラブルシューティング

- 評価時に `host guard` が原因で失敗する場合は `DISABLE_HOST_GUARD=1 nix build ...` を試行。/ Use `DISABLE_HOST_GUARD=1` when evaluating different hosts.
- `nix develop` で Python バージョンが必要な場合は `pythonVersions` を参照し `pkgs.buildPython` を利用。/ Custom Python builders are exposed via `pkgs.buildPython`.
- Hyprland 関連の不整合は `home-manager switch --flake .#<user>@<host>` で再適用。/ Re-run `home-manager switch` if Hyprland modules drift.

## Further Reading / 追加資料

- `hosts/darwin/README.md` — macOS 向けガイド。
- `AGENTS.md` と `CLAUDE.md` — MCP エージェントの利用方法。
- `tasks/*.md` — メンテナワークフロー手順書。

Happy hacking! / 楽しい Nix ライフを！
