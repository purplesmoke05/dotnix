# Brave left nixpkgs on 2026-11-03 (NixOS/nixpkgs#582838), so it is packaged here. / nixpkgs から削除された Brave をここで管理する。
# When the Ironbar NIX segment reports a newer Brave, run `make update-brave` and switch. / Ironbar の NIX に新しい Brave が出たら `make update-brave` を実行して切り替える。
{ callPackage }:

let
  version = "1.98.63";
  releaseBase = "https://github.com/brave/brave-browser/releases/download/v${version}";
in
callPackage
  (import ./make-brave.nix {
    pname = "brave";
    inherit version;

    archives = {
      aarch64-linux = {
        url = "${releaseBase}/brave-browser_${version}_arm64.deb";
        hash = "sha256-jQtKAVXCgQ7JwuK3VRWbmieL1R+50Nd2ynrE9C4MwvM=";
      };
      x86_64-linux = {
        url = "${releaseBase}/brave-browser_${version}_amd64.deb";
        hash = "sha256-JCJ81aklnr3FEI2zlMxZmN9aw2NfhPiDinRkp7XN3VU=";
      };
      aarch64-darwin = {
        url = "${releaseBase}/Brave-Browser-arm64.dmg";
        hash = "sha256-13XmtzqQIFTu3gj2aeIFDtbDaRJfhLbEsKd0biTBV7k=";
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
