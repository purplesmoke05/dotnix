{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, openssl
, zlib
, makeWrapper
}:

let
  version = "1.70.2";

  sources = {
    x86_64-linux = {
      url = "https://github.com/MystenLabs/sui/releases/download/mainnet-v${version}/sui-mainnet-v${version}-ubuntu-x86_64.tgz";
      hash = "sha256-4G6Sy1b10CWtwifQ68E/OZ9gMzrVfDFCfWX3hsoHp9Y=";
    };
    aarch64-linux = {
      url = "https://github.com/MystenLabs/sui/releases/download/mainnet-v${version}/sui-mainnet-v${version}-ubuntu-aarch64.tgz";
      hash = "sha256-0W0HeAo1HTBn9LIaf4hvldRTqUCBlYN+70dnhRPLN48=";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in

stdenv.mkDerivation rec {
  pname = "sui";
  inherit version;

  src = fetchurl {
    inherit (source) url;
    inherit (source) hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    openssl
    zlib
    stdenv.cc.cc.lib
  ];

  unpackPhase = ''
    tar -xzf $src
  '';

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/bin
    
    # Copy all executable files from the tarball
    for bin in sui sui-bridge sui-data-ingestion sui-faucet sui-graphql-rpc sui-indexer sui-node sui-test-validator sui-tool; do
      if [ -f "$bin" ]; then
        install -m755 "$bin" $out/bin/
      fi
    done
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Sui blockchain client and development tools";
    homepage = "https://sui.io";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "sui";
  };
}
