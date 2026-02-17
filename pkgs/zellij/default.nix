{ lib
, stdenv
, rustPlatform
, fetchFromGitHub
, mandown
, installShellFiles
, pkg-config
, curl
, openssl
, writableTmpDirAsHomeHook
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "zellij";
  version = "0.44.0-unstable-2026-02-12";

  src = fetchFromGitHub {
    owner = "zellij-org";
    repo = "zellij";
    rev = "90da559f381417a6fba16758c10aeef85cd378a6";
    hash = "sha256-mD2vLkq5rBpyvjHOsND01C16eQ7MjGj5KoIfnFcz5Og=";
  };

  postPatch = ''
    substituteInPlace Cargo.toml \
      --replace-fail ', "vendored_curl"' ""
  '';

  cargoHash = "sha256-4aKcQX4+9zoT4bFJzV6rqqw+aaj0ZUJ65xwVnIcrx18=";

  env.OPENSSL_NO_VENDOR = 1;
  doCheck = false;

  nativeBuildInputs = [
    mandown
    installShellFiles
    pkg-config
    (lib.getDev curl)
  ];

  buildInputs = [
    curl
    openssl
  ];

  nativeCheckInputs = [
    writableTmpDirAsHomeHook
  ];

  postInstall = ''
    mandown docs/MANPAGE.md > zellij.1
    installManPage zellij.1
  ''
  + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd $pname \
      --bash <($out/bin/zellij setup --generate-completion bash) \
      --fish <($out/bin/zellij setup --generate-completion fish) \
      --zsh <($out/bin/zellij setup --generate-completion zsh)
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Terminal workspace with batteries included";
    homepage = "https://zellij.dev/";
    changelog = "https://github.com/zellij-org/zellij/blob/main/CHANGELOG.md";
    license = with lib.licenses; [ mit ];
    maintainers = with lib.maintainers; [ ];
    mainProgram = "zellij";
  };
})
