{ lib
, stdenvNoCC
, fetchFromGitHub
, bun
, which
, writeShellScript
}:

let
  version = "0.1.0";
  revision = "be6888b71cf4eb5939ee79a746bd1a1c22ade046";
  browserRuntime = writeShellScript "herdr-browser-runtime" ''
    export PATH=${lib.escapeShellArg (lib.makeBinPath [ which ])}:"$PATH"
    ${lib.optionalString stdenvNoCC.hostPlatform.isDarwin ''
      export HERDR_BROWSER_CHROME=${lib.escapeShellArg "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"}
    ''}
    exec ${lib.getExe bun} "$@"
  '';
in
stdenvNoCC.mkDerivation {
  pname = "herdr-browser-plugin";
  inherit version;

  src = fetchFromGitHub {
    owner = "ogulcancelik";
    repo = "herdr-browser";
    rev = revision;
    hash = "sha256-4Dlo4YQpLPJKEPuXSS4EO5LMCmUn/tezEiIqlFXhCxo=";
  };

  postPatch = ''
    substituteInPlace herdr-plugin.toml \
      --replace-fail '"bun", "run"' '"${browserRuntime}", "run"'
  '';

  dontConfigure = true;
  dontBuild = true;

  nativeCheckInputs = [ bun ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    bun test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R . "$out/"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    grep -F ${lib.escapeShellArg browserRuntime} "$out/herdr-plugin.toml" >/dev/null
    runHook postInstallCheck
  '';

  passthru.pluginId = "official.browser";

  meta = {
    description = "Interactive Chromium pane and CDP bridge for Herdr";
    homepage = "https://github.com/ogulcancelik/herdr-browser";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
