{ lib
, buildNpmPackage
, bun
, fetchurl
, makeWrapper
, writableTmpDirAsHomeHook
}:

buildNpmPackage rec {
  pname = "pi";
  version = "0.81.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha512-r6ovAsZOgAqbC/aU6s+/dPnv/sGZBuWyZNvi3pXjpbuX5wvp3XvGkQI7/VLvX2o9XpmpFaPUxKNym1WfkN/P8A==";
  };

  sourceRoot = "package";
  npmDepsHash = "sha256-HG+prCqmA/NBzO56NdnYxYZuauiGWA/IkUgRwlsoqBc=";
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
