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
  version = "0.44.1";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    tag = "v${finalAttrs.version}";
    hash = "sha256-5AN/sK0IOIqcLX0FviFPOJ9QX9xJpliSN1XY3isxyrA=";
  };

  strictDeps = true;
  __structuredAttrs = true;

  cargoHash = "sha256-Hd8dy0atCeTie2rZ3nfpbwbTHrIueNlXo7kpmK6QQNU=";

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
