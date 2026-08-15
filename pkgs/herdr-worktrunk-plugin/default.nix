{ lib
, stdenvNoCC
, fetchFromGitHub
, makeWrapper
, bash
, coreutils
, fzf
, gawk
, gitMinimal
, gnused
, jq
, worktrunk
}:

let
  minimumWorktrunkVersion = "0.60.0";
  runtimeInputs = [
    bash
    coreutils
    fzf
    gawk
    gitMinimal
    gnused
    jq
    worktrunk
  ];
  runtimeBins = map (package: "${lib.getBin package}/bin") runtimeInputs;
  runtimePath = lib.makeBinPath runtimeInputs;
in
assert lib.assertMsg (lib.versionAtLeast worktrunk.version minimumWorktrunkVersion)
  "herdr-worktrunk-plugin requires worktrunk >= ${minimumWorktrunkVersion}, but received ${worktrunk.version}";
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-worktrunk-plugin";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "devashish2203";
    repo = "herdr-worktrunk";
    rev = "v${finalAttrs.version}";
    hash = "sha256-+G4EzlQisIr8SQ1NwDfzV/27iOiC3r/2nkxjcV/aU/k=";
  };

  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [
    bash
    coreutils
    gitMinimal
    gnused
  ];

  postPatch = ''
    substituteInPlace herdr-plugin.toml \
      --replace-fail 'version = "0.1.0"' 'version = "${finalAttrs.version}"' \
      --replace-fail 'command = ["bash", "-c"' 'command = ["${lib.getExe bash}", "-c"' \
      --replace-fail 'exec bash \"$HERDR_PLUGIN_ROOT/' 'exec ${lib.getExe bash} \"$HERDR_PLUGIN_ROOT/' \
      --replace-fail 'cwd=$(jq -r' 'cwd=$(${lib.getExe jq} -r'
  '';

  dontConfigure = true;
  dontBuild = true;

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ${lib.getExe bash} tests/config_test.sh
    ${lib.getExe bash} tests/helpers_test.sh
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R . "$out/"

    for script in picker.sh remove.sh; do
      wrapProgram "$out/$script" \
        --prefix PATH : ${lib.escapeShellArg runtimePath}
    done

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test -f "$out/herdr-plugin.toml"
    test -x "$out/picker.sh"
    test -x "$out/remove.sh"
    grep -F 'version = "${finalAttrs.version}"' "$out/herdr-plugin.toml" >/dev/null
    grep -F 'command = ["${lib.getExe bash}", "-c"' "$out/herdr-plugin.toml" >/dev/null
    grep -F 'cwd=$(${lib.getExe jq} -r' "$out/herdr-plugin.toml" >/dev/null
    for runtimeBin in ${lib.concatStringsSep " " (map lib.escapeShellArg runtimeBins)}; do
      grep -F "$runtimeBin" "$out/picker.sh" >/dev/null
      grep -F "$runtimeBin" "$out/remove.sh" >/dev/null
    done

    runHook postInstallCheck
  '';

  passthru = {
    pluginId = "worktrunk";
    inherit minimumWorktrunkVersion;
    worktrunkVersion = worktrunk.version;
  };

  meta = {
    description = "Herdr plugin for managing Git worktrees through Worktrunk";
    homepage = "https://github.com/devashish2203/herdr-worktrunk";
    changelog = "https://github.com/devashish2203/herdr-worktrunk/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
