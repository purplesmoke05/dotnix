{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, gitMinimal
, versionCheckHook
}:

let
  version = "0.51.0";
  sources = {
    x86_64-linux = {
      asset = "rtk-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-UCjTsZqPCZDTD+yfuwfjJ4K8VpjmGPsYYarYqcy6TrU=";
    };
    aarch64-linux = {
      asset = "rtk-aarch64-unknown-linux-gnu.tar.gz";
      hash = "sha256-jW0arZ5ptCSB7acDlQfR9+6TaY+HcTzs2HPSh8GTFjI=";
    };
    x86_64-darwin = {
      asset = "rtk-x86_64-apple-darwin.tar.gz";
      hash = "sha256-vTnIFT9BRzWDYMfcUWZagTHMnuFvgfaalAL/pQC+PMI=";
    };
    aarch64-darwin = {
      asset = "rtk-aarch64-apple-darwin.tar.gz";
      hash = "sha256-iBfYtxr8AqyL8G6yS8xBwwZZKrc1to6P7p2xug3ny1k=";
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
