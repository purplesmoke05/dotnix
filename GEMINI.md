# Repository Guidelines / リポジトリガイドライン

Responses must be in Japanese. / 返答は日本語のみで行うこと。

## Project Structure & Module Organization / プロジェクト構成とモジュール

- `flake.nix`: Entry point for hosts, overlays, dev shells, formatter / フレークの入口（ホスト・オーバーレイ・開発シェル・フォーマッタ）。
- `hosts/`: Machine configs / マシン別設定
  - `nixos/common/` (shared) and `nixos/<host>` (e.g., `laptop`, `hq`) / 共有とホスト別設定。
  - `darwin/`: Experimental macOS support / 実験的な macOS 対応。
- `home-manager/`: User env modules by area (`cli/`, `gui/`, `wm/`, `development`) / 分野別ユーザー環境モジュール。
- `pkgs/`: Custom packages (e.g., `codex/`, `sui/`), each with `default.nix` / 各パッケージは専用ディレクトリ＋`default.nix`。
- `shells/`: Extra dev shells (e.g., `shells/node.nix`) / 追加の開発シェル。
- `tasks/`: Maintainer workflows / 運用ワークフロー。

## Build, Test, and Development Commands / ビルド・テスト・開発コマンド

- Enter dev shell / 開発シェルに入る: `nix develop`, `nix develop .#rust`, `.#py312`。
- Format Nix / フォーマット: `nix fmt`（`nixpkgs-fmt`）。
- Validate flake / 検証: `nix flake check`。
- Dry build system / ドライビルド: `nixos-rebuild build --flake .#<host>`。
- Apply system / 反映: `sudo nixos-rebuild switch --flake .#<host>`（`laptop`, `hq`）。
- Update inputs / 依存更新: `nix flake update`。

## Coding Style & Naming Conventions / コーディング規約・命名

- Nix: 2-space indent; small, composable modules / インデント2スペース・小さなモジュール化。
- Filenames / ファイル名: `snake-case.nix`；packages in `pkgs/<name>/default.nix`。
- Scope / 置き場所: host-specific → `hosts/nixos/<host>/`、shared → `hosts/nixos/common/`・`home-manager/*`。
- Run `nix fmt` before commits; avoid unrelated churn / コミット前に `nix fmt`、無関係変更は避ける。
- Bilingual comments: write `English sentence. / 日本語訳。` on a single line; delete stale or redundant comments. / バイリンガルコメントは1行に「英語文。/ 日本語訳。」の順で記述し、冗長・陳腐化したコメントは削除する。

## Testing Guidelines / テスト指針

- Always run / 常に実行: `nix flake check`。
- NixOS changes / NixOS 変更: `nixos-rebuild build --flake .#<host>` または `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`。
- Home Manager modules / HM変更: 上記のホストで `switch` を試験。必要に応じ最小再現設定を追加。

## Commit & Pull Request Guidelines / コミットとPR指針

- Style / スタイル: Conventional Commits（例: `feat: ...`, `fix(scope): ...`, `chore: ...`）。Subject の先頭に適切な絵文字を必ず付与（必須）。
- Emoji examples / 絵文字例: ✨ feat, 🐛 fix, 📝 docs, ♻️ refactor, ✅ test, ⚡️ perf, 🧪 ci, 🧹 chore, 🏗️ build, ⏪ revert。
- Subject / 件名: 命令形・約72文字。本文で背景説明；`Closes #123` で Issue 連携。
- Pre-PR checks / 事前確認: `nix fmt` と `nix flake check` を通す。変更点・理由・影響ホストを記載。UI系はスクリーンショット添付。

## Security & Configuration Tips / セキュリティと設定

- Secrets / シークレット:
  - コミット禁止（Nixストアにも平文を置かない）。
  - ユーザー/アプリ用（MCP・Home Manager 経由のCLI等）は `~/.config/mcp-secrets/` を使用。
  - システムサービス用（例: hostapd, wireguard, など）はホーム外のランタイム/永続領域を使用（例: `/var/lib/<service>/…`）。
    - 例: hostapd のパスフレーズは `/var/lib/hostapd/hotspot.pass`（root:root, 0600; リポジトリ非管理）。
    - sops-nix/agenix等のシークレットマネージャ採用も歓迎。
- User/Host guard / ユーザー・ホストガード: `LAPTOP_USER`/`HQ_USER`/`DARWIN_USER` で上書き可。クロスホスト評価時のみ `DISABLE_HOST_GUARD=1`。
- Locale & IME / ロケール・IME: `ja_JP.UTF-8` と `fcitx5-mozc` を `hosts/nixos/common/nixos.nix` で設定済み（追加作業不要）。
- MCP: See `CLAUDE.md` for agent use / エージェント利用は `CLAUDE.md` を参照。

## Bladebro / ブラウザ自動化

- Tools: `act` (do), `see` (observe), `state` (tabs/cookies/login), `run` (branch/loop), `vision` (screenshot, last resort). / ツールは `act`・`see`・`state`・`run`・`vision`。
- Hierarchy: `act` text > ref > label. Forms → `fill`. Sequences → `batch`. Branching → `run`. / 指定は text > ref > label。フォームは `fill`、連続操作は `batch`、分岐は `run`。
- `see`: outline (最安) → content (閲覧) → model (ref 取得)。Listings → `extract=auto`. / `see` は outline → content → model。一覧は `extract=auto`。
- Chrome runs on Xvfb `:99` with a separate profile under `~/.blade/`; it does not share the user's Brave session. / Chrome は Xvfb `:99` 上の別プロファイルで、普段のブラウザとは共有しない。
