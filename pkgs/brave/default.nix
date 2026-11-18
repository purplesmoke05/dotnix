# Brave left nixpkgs on 2026-11-03 (NixOS/nixpkgs#582838), so it is packaged here. / nixpkgs から削除された Brave をここで管理する。
# When the Ironbar NIX segment reports a newer Brave, run `make update-brave` and switch. / Ironbar の NIX に新しい Brave が出たら `make update-brave` を実行して切り替える。
{ callPackage }:

let
  version = "1.99.57";
  releaseBase = "https://github.com/brave/brave-browser/releases/download/v${version}";
in
callPackage
  (import ./make-brave.nix {
    pname = "brave";
    inherit version;

    archives = {
      aarch64-linux = {
        url = "${releaseBase}/brave-browser_${version}_arm64.deb";
        hash = "sha256-0F30+KjElAdSRoIMF4l6RpYU+HmTindVfwJf2nvmHbQ=";
      };
      x86_64-linux = {
        url = "${releaseBase}/brave-browser_${version}_amd64.deb";
        hash = "sha256-jNFMV/f9bXnf2aJUUBdbVDihsRtWX/XQitmRtwLen9U=";
      };
      aarch64-darwin = {
        url = "${releaseBase}/Brave-Browser-arm64.dmg";
        hash = "sha256-kik0sjPd7PpJqdxWKdQEaf2wstWcSVR2l+6g7sQIdxE=";
      };
    };

    optStem = "brave";
    fileStem = "brave-browser";
    appIdStem = "com.brave.Browser";
    darwinStem = "Brave Browser";
    changelogFile = "CHANGELOG_DESKTOP.md";
    homepage = "https://brave.com/";
    innerBinary = "brave";
  })
{ }
