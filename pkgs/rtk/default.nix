{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, gitMinimal
, versionCheckHook
}:

let
  version = "1.1.0";
  sources = {
    x86_64-linux = {
      asset = "rtk-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-lFStG5SJ2qV6sKn06+L6r03IK4oPJsnlE1FRq9fJN40=";
    };
    aarch64-linux = {
      asset = "rtk-aarch64-unknown-linux-gnu.tar.gz";
      hash = "sha256-pcAMOrASmIS8t1fTSK/BplDvoPTwdp2pfDQfKPiXGe0=";
    };
    x86_64-darwin = {
      asset = "rtk-x86_64-apple-darwin.tar.gz";
      hash = "sha256-HiPouVQrWEKOZAnEmxw/uSxMDVEl2nLoDwAqRghqbCA=";
    };
    aarch64-darwin = {
      asset = "rtk-aarch64-apple-darwin.tar.gz";
      hash = "sha256-jadzsJVM+QsRXslcTk60IPBMOd4jPF2xAiRqbK8HO6c=";
    };
  };
  srcConfig = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "rtk";
  inherit version;

  src = fetchurl {
    url = "https://github.com/rtk-ai/rtk/releases/download/v${finalAttrs.version}/${srcConfig.asset}";
    inherit (srcConfig) hash;
  };

  strictDeps = true;
  __structuredAttrs = true;
  sourceRoot = ".";
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = [ makeWrapper ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals (stdenv.hostPlatform.system == "aarch64-linux") [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 rtk $out/bin/rtk
    wrapProgram $out/bin/rtk \
      --prefix PATH : ${lib.makeBinPath [ gitMinimal ]}
    runHook postInstall
  '';

  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  doInstallCheck = true;

  passthru.updateScript = ./update.sh;

  meta = {
    description = "CLI proxy that reduces LLM token consumption on common dev commands";
    homepage = "https://github.com/rtk-ai/rtk";
    changelog = "https://github.com/rtk-ai/rtk/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "rtk";
    platforms = lib.attrNames sources;
  };
})
