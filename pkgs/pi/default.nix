{ lib
, buildNpmPackage
, bun
, fetchurl
, makeWrapper
, writableTmpDirAsHomeHook
}:

buildNpmPackage rec {
  pname = "pi";
  version = "1.5.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha512-xNDZ5kqowO6Z03FS2gwAkPEGk1ssxVcYKQ6qZId84mFEvwACvvyc2l0vAMOS+c5zvxLRMLBE9r4y44IGYkMJaQ==";
  };

  sourceRoot = "package";
  npmDepsHash = "sha256-WniS4qTcE3+ly5bNLIfQLh7NxBJZHIsliIyKGAiJlnk=";
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
