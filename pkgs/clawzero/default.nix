{ lib
, stdenv
, fetchurl
, autoPatchelfHook ? null
}:

let
  version = "0.1.2";

  targets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-SLdpyf3srbRAv/Y0NcGs+/5rsByiS2LAKAp0df6l1As=";
      nativeBuildInputs = lib.filter (x: x != null) [ autoPatchelfHook ];
      buildInputs = [ stdenv.cc.cc.lib ];
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-gDwJ3BXUJJJUdLHDfHK+yZnES7JuRZgMG+3yQxdmwo8=";
      nativeBuildInputs = lib.filter (x: x != null) [ autoPatchelfHook ];
      buildInputs = [ stdenv.cc.cc.lib ];
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-4YH0wc8wuXfV87fHjJBkOVx6/ISBxxLdbZKaWGqQ1qc=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-3yAE77AIBGY+4F/zVuyRd9QrGnhTlPY9K+EIKCTV/mo=";
    };
  };

  source = targets.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation rec {
  pname = "clawzero";
  inherit version;

  src = fetchurl {
    url = "https://github.com/betta-lab/clawzero/releases/download/v${version}/clawzero-v${version}-${source.target}.tar.gz";
    hash = source.hash;
  };

  nativeBuildInputs = source.nativeBuildInputs or [ ];
  buildInputs = source.buildInputs or [ ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "./clawzero" "$out/bin/clawzero"
    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Ultra-fast, stable AI agent CLI built in Rust";
    homepage = "https://github.com/betta-lab/clawzero";
    mainProgram = "clawzero";
    license = lib.licenses.unfree;
    platforms = builtins.attrNames targets;
  };
}
