{ lib
, fetchurl
, makeWrapper
, nodejs_22
, stdenvNoCC
, icu
}:

stdenvNoCC.mkDerivation rec {
  pname = "workiq";
  version = "0.4.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@microsoft/workiq/-/workiq-${version}.tgz";
    hash = "sha256-sTG5YKZSmE57YlaJ6xRaBAewi9qJmsF48lsOxCJZXyA=";
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"/{bin,share/workiq}
    tar -xzf "$src" --strip-components=1 -C "$out/share/workiq"

    find "$out/share/workiq/bin" -type f -name workiq -exec chmod 755 {} +

    makeWrapper ${nodejs_22}/bin/node "$out/bin/workiq" \
      --add-flags "$out/share/workiq/bin/workiq.js" \
      ${lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ icu ]}"
      ''}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Work IQ CLI for Microsoft 365";
    homepage = "https://github.com/microsoft/work-iq-mcp";
    license = licenses.unfree;
    mainProgram = "workiq";
    platforms = platforms.darwin ++ platforms.linux;
  };
}
