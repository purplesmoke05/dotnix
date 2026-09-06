{ lib
, buildNpmPackage
, bun
, fetchurl
, makeWrapper
, writableTmpDirAsHomeHook
}:

buildNpmPackage rec {
  pname = "pi";
  version = "0.85.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha512-FGRN+OHbWaefBPGaTggAdLjrIHW+s2PzLyglz/5dfLzb9of7uuXMXYC0fJIeZTw+shS32o2cuQ9jF7YSDuL/oQ==";
  };

  sourceRoot = "package";
  npmDepsHash = "sha256-w3l4fPKU7gI8se0Rrw8gtDtj0/4DojCuIVZKosUH3cg=";
  dontNpmBuild = true;
  npmInstallFlags = [
    "--ignore-scripts"
    "--omit=dev"
  ];
  nativeBuildInputs = [
    makeWrapper
  ];

  postPatch = ''
    rm -f npm-shrinkwrap.json
    cp ${./package.json} package.json
    cp ${./package-lock.json} package-lock.json
  '';

  postInstall = ''
    rm -f "$out/bin/pi"
    makeWrapper ${lib.getExe bun} "$out/bin/pi" \
      --add-flags "$out/lib/node_modules/@earendil-works/pi-coding-agent/dist/cli.js"
  '';

  postFixup = ''
    while IFS= read -r file; do
      sed -i "1s|^#!.*node$|#!${lib.getExe bun}|" "$file"
    done < <(grep -RIl "^#!.*node$" "$out/lib/node_modules/@earendil-works/pi-coding-agent" || true)
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
  ];
  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR" "$out/bin/pi" --version >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Minimal, self-extensible AI coding agent CLI";
    homepage = "https://pi.dev";
    changelog = "https://github.com/earendil-works/pi/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "pi";
    platforms = lib.platforms.all;
  };
}
