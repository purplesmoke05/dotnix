{ lib
, rustPlatform
, fetchFromGitHub
, makeWrapper
, pkg-config
, sqlite
, gitMinimal
, writableTmpDirAsHomeHook
, versionCheckHook
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "rtk";
  version = "0.39.0";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    tag = "v${finalAttrs.version}";
    hash = "sha256-TX4MtR/rq61wxHWYJAO2x3CYvZtkCoXynf45dRC+MVo=";
  };

  strictDeps = true;
  __structuredAttrs = true;

  cargoHash = "sha256-s3AtUftUZtzhlep8R/ZuxwmGELIZpqbQXqLTD+aS4Ro=";

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];

  buildInputs = [
    sqlite
  ];

  postInstall = ''
    wrapProgram $out/bin/rtk \
      --prefix PATH : ${lib.makeBinPath [ gitMinimal ]}
  '';

  nativeCheckInputs = [
    gitMinimal
    writableTmpDirAsHomeHook
  ];

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
  };
})
