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
  version = "0.47.0";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    tag = "v${finalAttrs.version}";
    hash = "sha256-qYVkFLS6G4Tf1NmD9B3kJkyb47XREoVE65EqBtbzzjs=";
  };

  strictDeps = true;
  __structuredAttrs = true;

  cargoHash = "sha256-2lwLPia3v7xagKsrCpayixZMmOqX15qrjsVP8/RQCXE=";

  patches = [
    ./registry-load-test.patch
  ];

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
