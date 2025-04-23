{ pkgs, inputs, lib, ... }:

let
  # 元のパッケージを取得
  claudeOriginal = inputs.claude-desktop.packages.${pkgs.system}.claude-desktop-with-fhs;

  # Waylandフラグ付きでラップする
  claudeWrapped = claudeOriginal.overrideAttrs (oldAttrs: {
    # wrapProgram を使うために makeWrapper をビルド時依存に追加
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];

    # postFixup フェーズで実行ファイルをラップする
    # (installPhase や fixupPhase の後、最終的な $out が準備される前あたりで実行される)
    postFixup = (oldAttrs.postFixup or "") + ''
      wrapProgram $out/bin/claude-desktop \
        --add-flags "--enable-features=UseOzonePlatform --ozone-platform=x11 --enable-wayland-ime=true --disable-gpu"
    '';
  });

in
{
  # Allow unfree packages for Claude Desktop
  # nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #   "claude-desktop-with-fhs"
  # ];

  home.packages = [
    # ラップされたパッケージを使用
    claudeWrapped
  ];
}
