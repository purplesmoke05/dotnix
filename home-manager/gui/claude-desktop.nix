{ pkgs, inputs, lib, ... }:

let
  # Fetch the original package / 元のパッケージを取得
  claudeOriginal = inputs.claude-desktop.packages.${pkgs.system}.claude-desktop-with-fhs;

  # Wrap with Wayland flags / Wayland フラグ付きでラップ
  claudeWrapped = claudeOriginal.overrideAttrs (oldAttrs: {
    # Add makeWrapper to use wrapProgram / wrapProgram を使うために makeWrapper を追加
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];

    # Wrap the binary during postFixup / postFixup フェーズで実行ファイルをラップ
    # Runs after install/fixup, before final $out / installPhase・fixupPhase 後、最終 $out 前に実行
    postFixup = (oldAttrs.postFixup or "") + ''
      wrapProgram $out/bin/claude-desktop \
        --add-flags "--enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime=true"
    '';
  });

in
{
  # Allow unfree packages for Claude Desktop
  # nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #   "claude-desktop-with-fhs"
  # ];

  home.packages = [
    # Use the wrapped package / ラップされたパッケージを使用
    claudeWrapped
  ];
}
