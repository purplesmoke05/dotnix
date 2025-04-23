# Issue に基づく機能実装ワークフロー

このドキュメントは、`check_update` タスクによって作成された Issue を調査し、提案された変更を `purplesmoke05/dotnix` リポジトリに実装する手順を概説します。

**始める前に:** まず、`https://github.com/purplesmoke05/dotnix/issues` で**未クローズ (Open)** かつ **`backlog` ラベルが付いていない Issue** を確認し、実装したいものを **1つ選択**してください。以下の説明では、選択した Issue の番号を `#{issue_number}` として扱います。

## 1. Issue の調査

*   **Issue の読解:** GitHub 上の選択した Issue `#{issue_number}` の説明と詳細を注意深く読みます。
*   **変更内容の理解:** 元のリポジトリ (`${TARGET_OWNER}/${TARGET_REPO}`) から提案された変更と、Issue 本文で提示された実装の詳細を確認します。どの Nix ファイル (`flake.nix`, `home-manager/**/*.nix`, `hosts/**/*.nix`, `pkgs/**/*.nix`) を変更する必要があるかに特に注意を払います。変更の根拠と潜在的な影響を分析します。

## 2. 調査結果の Issue への追記 (New Step)

*   **結果の記録:** 調査した内容（例: 提案されたツールの目的、変更によるメリット、潜在的な懸念点、関連情報など）を明確にまとめます。
*   **コメント投稿:** GitHub の Issue `#{issue_number}` に、調査結果をコメントとして投稿します。これにより、実装判断の根拠や経緯が Issue 上に記録され、後から参照しやすくなります。
    *   **コメント例:** `調査の結果、zoxide は頻繁にアクセスするディレクトリへの移動を効率化し、atuin はコマンド履歴の検索性を向上させるツールであることが分かりました。既存の設定との衝突は考えにくく、CLI の利便性向上が期待できるため、提案通り実装を進めます。`

## 3. 実装計画（変更案の作成）

調査に基づいて、必要な具体的なコード変更案を作成します。関連する各ファイルの変更を準備します。

*   **変更計画の例:**
    *   **ファイル:** `home-manager/cli/git.nix`
        ```nix
        # git.nix に対する変更案
        programs.git = {
          enable = true;
          userName = "あなたの名前";
          userEmail = "あなたのメールアドレス@example.com";
          extraConfig = {
            init.defaultBranch = "main";
            # core.editor = "nvim"; # 古い設定
            core.editor = "vim";   # Issue 分析に基づく新しい設定
          };
          # Issue で要求されている場合は新しい設定を追加
          signing = {
            key = "YOUR_GPG_KEY";
            signByDefault = true;
          };
        };
        ```
    *   **ファイル:** `hosts/common/nixos.nix`
        ```nix
        # nixos.nix に対する変更案
        environment.systemPackages = with pkgs; [
          # ... 既存のパッケージ ...
          ripgrep # Issue で提案されたパッケージを追加
          fd      # 別の関連パッケージを追加
        ];
        ```
    *   **(Issue に基づいて、すべてのファイルとその計画された変更をリストアップします)**

**計画した変更が正確であり、潜在的な副作用がないかを徹底的にレビューします。**

## 4. 決定: 変更を実装しますか？

*   **評価:** 提案された変更は、あなたのシステム構成の目標や好みに合致していますか？ 既存の設定との潜在的な衝突や意図しない結果を考慮しましたか？
*   **決定:** 評価に基づき、これらの変更をあなたの設定に実装するかどうかを決定します。

**実装しないと決定した場合:**
*   GitHub で Issue `#{issue_number}` をクローズします。
*   実装しない理由（例: 衝突、変更が望ましくない）を説明するコメントを追加します。

**実装すると決定した場合:**
*   以下に概説する次のステップに進みます。

## 5. 実装手順

ローカルの `dotnix` リポジトリクローン内のターミナルで、これらの手順を正確に実行します。

1.  **`main` ブランチを最新の状態にする:**
    ```bash
    git checkout main
    git pull origin main
    ```
2.  **フィーチャーブランチの作成:** 選択した Issue 専用の新しいブランチを作成します。`feature/#{issue_number}` の形式を使用します。
    ```bash
    git checkout -b feature/#{issue_number}
    ```
3.  **変更の適用:** ステップ 3 の計画に従って、Nix ファイル (`flake.nix`, `home-manager/**/*.nix`, `hosts/**/*.nix`, `pkgs/**/*.nix` など) を変更します。お好みのテキストエディタまたは IDE を使用します。
4.  **コードのフォーマット:** 変更した Nix ファイルに一貫したフォーマットを適用します。
    ```bash
    nix fmt
    ```
    *   **(注意)** もし `nix fmt` コマンドが応答なし（スタック）になる場合は、代わりに以下のコマンドを使用してください:
        ```bash
        find . -name '*.nix' -print0 | xargs -0 nix fmt
        ```
5.  **ローカルビルドテスト:** 変更が正常にビルドされ、エラーが発生しないことを確認します。
    *   **優先コマンド:** 包括的な flake チェックを実行します。
        ```bash
        nix flake check --no-build --print-build-logs
        ```
    *   **代替コマンド (特定のターゲットをテストする場合):** `<hostname>` や `<username>` のようなプレースホルダーを実際の値に置き換えます。
        ```bash
        # オプション: 特定ホストの NixOS 設定をテスト
        # nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --no-link --print-out-paths

        # オプション: 特定ユーザー/ホストの Home Manager 設定をテスト
        # nix build .#homeConfigurations."<username>@<hostname>".activationPackage --no-link --print-out-paths
        ```
    *   **重要:** ビルド (`nix flake check` を含む) が失敗した場合、エラーメッセージを注意深く確認します。Nix コードをデバッグし、問題を修正し、ビルドが成功するまで **ステップ 4 (フォーマット) と 5 (ビルドテスト)** を繰り返します。
6.  **変更のステージング:** 変更したファイルを Git のステージングエリアに追加します。追加するファイルを明示的に指定します。
    ```bash
    git add flake.nix home-manager/cli/git.nix hosts/common/nixos.nix # 変更したすべてのファイル/ディレクトリを明示的に追加
    ```
    *   *(コミットする前に `git status` と `git diff --staged` を使用してステージングされた変更を確認します。)*
7.  **変更のコミット:** ステージングされた変更を、明確で説明的なメッセージ（**英語で**）と共にコミットします。
    *   `@check_update.md` のルールと同様に、メッセージの**先頭に適切な絵文字** (例: ✨ `feat`, 🐛 `fix`, 📝 `docs`, 🔧 `chore`, 🎨 `style`, 🚀 `perf`, 🧪 `test`, ♻️ `refactor`, 📦 `build`, ⚙️ `ci`, ⏪ `revert`, ⬆️ `deps`) を付与してください。
    *   従来のコミットメッセージ形式に従いますが、タイトルの先頭に `feat:` や `fix:` のような接頭辞や `(スコープ):` は含めません。
    *   コミットメッセージの**本文**に Issue 番号を記載します。
    ```bash
    # コミットメッセージの例 (英語で記述、先頭に絵文字、スコープなし)
    git commit -m "✨ Implement git editor and add CLI tools" -m "Updates git core.editor setting based on Issue #{issue_number}. Adds ripgrep and fd packages as suggested by the upstream changes in ${TARGET_OWNER}/${TARGET_REPO}."
    ```
    *   *(行った変更を正確に反映するように、絵文字、コミットメッセージのタイトルと本文をカスタマイズします。)*
8.  **ブランチのプッシュ:** 新しいフィーチャーブランチをリモートリポジトリ (`origin`) にプッシュします。最初のプッシュでアップストリーム追跡ブランチを設定します。
    ```bash
    git push -u origin feature/#{issue_number}
    ```
9.  **プルリクエストの作成 (AI が実行):**
    *   AI (MCP) がプッシュされた `feature/#{issue_number}` ブランチから `main` ブランチへのプルリクエストを作成します。
    *   **タイトル:** コミットメッセージを反映した簡潔なタイトルを使用します（例: `✨ Implement git editor and add CLI tools`）。タイトルには絵文字を含めますが、先頭に `feat:` や Issue 番号 `(#{issue_number})` は含めません。
    *   **本文:** AI が変更の簡単な説明を提供します。重要な点として、説明本文に `Closes #{issue_number}` または `Fixes #{issue_number}` を含めることで元の Issue にリンクします。これにより、PR がマージされたときに Issue が自動的にクローズされます。
    *   **レビュー担当者/担当者:** AI が、該当する場合は自分自身または関連するレビュー担当者を割り当てます。
    *   **ラベル:** AI が `enhancement`、`bug`、または関連する場合はソースリポジトリのラベル (`${TARGET_OWNER}/${TARGET_REPO}`) など、適切なラベルを追加します。

## 6. レビューとマージ

*   プルリクエストのチェック（自動テスト、ビルド、リンター）を監視し、すべてパスすることを確認します。

---
*このワークフロードキュメントは、監視対象リポジトリの更新に基づいて変更を実装するプロセスを効率化するために、Gemini と Cursor Agent の支援を受けて生成されました。*
