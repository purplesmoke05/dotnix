{ lib
, stdenvNoCC
, fetchFromGitHub
, fetchurl
, bash
, coreutils
, gawk
, writeShellScript
, writableTmpDirAsHomeHook
}:

let
  version = "0.5.23";

  # Map Nix systems to Agent Usage release assets. / Nix system を Agent Usage の release asset に対応付ける。
  sources = {
    x86_64-linux = {
      asset = "usagebar-linux-amd64";
      hash = "sha256-kED+ILKDDCBtR+gHSvmzHNGZiDQQKrALpVeyM4PN/jU=";
    };
    aarch64-linux = {
      asset = "usagebar-linux-arm64";
      hash = "sha256-fKMnsZxDmUNGdi53kEh8PoPrYpjtZQkHYi8cTlr/rTo=";
    };
    x86_64-darwin = {
      asset = "usagebar-darwin-amd64";
      hash = "sha256-U/1x8Yu+uHJsWAeN1kIYM0yzhQ5YiRGdLa23pkGX2uo=";
    };
    aarch64-darwin = {
      asset = "usagebar-darwin-arm64";
      hash = "sha256-45pwlwBY3DOmS70bTkJSo1Uln+s+qrnLIOfZMYaGQ/Q=";
    };
  };

  srcConfig = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");

  runtimeShell = writeShellScript "herdr-agent-usage-runtime" ''
    export PATH=${lib.escapeShellArg (lib.makeBinPath [ coreutils gawk ])}:"$PATH"
    exec ${lib.getExe bash} "$@"
  '';
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-agent-usage-plugin";
  inherit version;

  src = fetchFromGitHub {
    owner = "senna-lang";
    repo = "herdr-agent-usage";
    rev = "v${finalAttrs.version}";
    hash = "sha256-q3KuB11K/8xwcUIcvhX/bhlbdt3invPqHERBLcEjJhk=";
  };

  usagebarBinary = fetchurl {
    url = "https://github.com/senna-lang/herdr-agent-usage/releases/download/v${finalAttrs.version}/${srcConfig.asset}";
    inherit (srcConfig) hash;
  };

  postPatch = ''
    patchShebangs bin
    substituteInPlace herdr-plugin.toml \
      --replace-fail 'command = ["bash",' 'command = ["${runtimeShell}",'
  '';

  dontConfigure = true;
  dontBuild = true;
  # Preserve upstream release signatures on Darwin. / Darwin の upstream release 署名を保持する。
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cp -R . "$out/"
    install -m755 "$usagebarBinary" "$out/bin/usagebar"

    runHook postInstall
  '';

  nativeInstallCheckInputs = [ writableTmpDirAsHomeHook ];
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    export XDG_CONFIG_HOME="$TMPDIR/config"
    export XDG_STATE_HOME="$TMPDIR/state"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"

    test -f "$out/herdr-plugin.toml"
    test -x "$out/bin/usagebar"
    grep -F 'command = ["${runtimeShell}", "bin/run-status.sh"]' "$out/herdr-plugin.toml" >/dev/null
    ! grep -F 'command = ["bash",' "$out/herdr-plugin.toml" >/dev/null
    (
      cd "$out"
      ${runtimeShell} bin/ensure-binary.sh --in-tree
      ${runtimeShell} bin/run-usagebar.sh version | grep -Fx "usagebar v${finalAttrs.version}" >/dev/null
    )

    runHook postInstallCheck
  '';

  passthru.pluginId = "usagebar";

  meta = {
    description = "Herdr context meters, provider limits, and rate-limit notifications";
    homepage = "https://github.com/senna-lang/herdr-agent-usage";
    changelog = "https://github.com/senna-lang/herdr-agent-usage/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "usagebar";
    platforms = lib.attrNames sources;
  };
})
