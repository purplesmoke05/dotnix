{ pkgs ? import <nixpkgs> {} }:

let
  src = pkgs.fetchFromGitHub {
    owner = "kbwo";
    repo = "ccmanager";
    rev = "0.1.2";
    hash = "sha256-JYD0Ft0PhDN2Yauh6+pHwXoiYo+p9KCq3kWKFTtu8Xk=";
  };
in
pkgs.runCommand "get-npm-deps-hash" {
  nativeBuildInputs = [ pkgs.prefetch-npm-deps ];
} ''
  cd ${src}
  prefetch-npm-deps package-lock.json
''