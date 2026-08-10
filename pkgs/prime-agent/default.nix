{ lib
, stdenv
, buildNpmPackage
, nodejs_24
, fetchurl
, autoPatchelfHook ? null
, makeWrapper
, ripgrep
, uv
, writableTmpDirAsHomeHook
}:

let
  nodeOs =
    if stdenv.hostPlatform.isLinux then
      "linux"
    else if stdenv.hostPlatform.isDarwin then
      "darwin"
    else
      throw "Unsupported operating system: ${stdenv.hostPlatform.system}";
  nodeArch =
    if stdenv.hostPlatform.parsed.cpu.name == "x86_64" then
      "x64"
    else if stdenv.hostPlatform.parsed.cpu.name == "aarch64" then
      "arm64"
    else
      throw "Unsupported architecture: ${stdenv.hostPlatform.parsed.cpu.name}";
  koffiPlatform = "${nodeOs}_${nodeArch}";
in
buildNpmPackage rec {
  pname = "prime-agent";
  version = "0.7.1";
  nodejs = nodejs_24;

  src = fetchurl {
    url = "https://github.com/PrimeIntellect-ai/prime-agent/releases/download/v${version}/prime-agent-${version}.tgz";
    hash = "sha256-1oYSyDI5yq+rcsx2xVrFcr/QegWeqPvSo92+HytV3Ns=";
  };

  sourceRoot = "package";
  npmDepsHash = "sha256-5GokjUrkNCq/Vflq4DBcIxhcIhw+rYyOD9+7aCJAr/o=";
  dontNpmBuild = true;
  npmInstallFlags = [
    "--ignore-scripts"
    "--omit=dev"
  ];

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux (
    lib.filter (dependency: dependency != null) [ autoPatchelfHook ]
  );

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  postPatch = ''
    cp ${./package.json} package.json
    cp ${./package-lock.json} package-lock.json
  '';

  postInstall = ''
    zeromq_build="$out/lib/node_modules/prime-agent/node_modules/zeromq/build"
    if [ -d "$zeromq_build" ]; then
      find "$zeromq_build" -mindepth 1 -maxdepth 1 -type d ! -name ${lib.escapeShellArg nodeOs} -exec rm -rf {} +
      find "$zeromq_build/${nodeOs}" -mindepth 1 -maxdepth 1 -type d ! -name ${lib.escapeShellArg nodeArch} -exec rm -rf {} +
      ${lib.optionalString stdenv.hostPlatform.isLinux ''
        find "$zeromq_build/${nodeOs}/${nodeArch}/node" \
          -mindepth 1 -maxdepth 1 ! -name 'glibc-*' -exec rm -rf {} +
      ''}
    fi

    koffi_build="$out/lib/node_modules/prime-agent/node_modules/koffi/build/koffi"
    if [ -d "$koffi_build" ]; then
      find "$koffi_build" -mindepth 1 -maxdepth 1 -type d ! -name ${lib.escapeShellArg koffiPlatform} -exec rm -rf {} +
    fi

    rm -f "$out/bin/prime-agent"
    makeWrapper ${lib.getExe nodejs_24} "$out/bin/prime-agent" \
      --add-flags "$out/lib/node_modules/prime-agent/dist/bundle/cli.js" \
      --prefix PATH : "${lib.makeBinPath [ ripgrep uv ]}" \
      --set PI_SKIP_VERSION_CHECK 1
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
  ];
  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR" "$out/bin/prime-agent" --version >/dev/null
    runHook postInstallCheck
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Self-improving RLM coding and research agent";
    homepage = "https://github.com/PrimeIntellect-ai/prime-agent";
    changelog = "https://github.com/PrimeIntellect-ai/prime-agent/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "prime-agent";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
