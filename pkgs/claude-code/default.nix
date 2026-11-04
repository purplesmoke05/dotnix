{ lib
, stdenv
, fetchurl
, autoPatchelfHook ? null
, makeWrapper
, writableTmpDirAsHomeHook
, bubblewrap ? null
, procps ? null
, socat ? null
}:

let
  version = "2.1.317";
  releaseBase = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}";

  platform =
    let
      os =
        if stdenv.hostPlatform.isLinux then
          "linux"
        else if stdenv.hostPlatform.isDarwin then
          "darwin"
        else
          throw "Unsupported system: ${stdenv.hostPlatform.system}";

      arch =
        if stdenv.hostPlatform.parsed.cpu.name == "x86_64" then
          "x64"
        else if stdenv.hostPlatform.parsed.cpu.name == "aarch64" then
          "arm64"
        else
          throw "Unsupported architecture: ${stdenv.hostPlatform.parsed.cpu.name}";

      muslSuffix = if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isMusl then "-musl" else "";
    in
    "${os}-${arch}${muslSuffix}";

  hashes = {
    darwin-arm64 = "sha256-CfFTtGtd+eizRUcW1oKpGQHeAgy8pjD2HewaAVsytek=";
    darwin-x64 = "sha256-AccUvH/r2wCPKOP2+ssdw35GpNj6jbWN8uKB7lHLMzw=";
    linux-arm64 = "sha256-VjoNYK0MIj2UFXaCEJl6yw9xNOpR3Dwjjoi8Lhjd7vo=";
    linux-arm64-musl = "sha256-3IxZz5N+YOnMk6/iJu9DdHTe1WuoE3Q9CRBtJKCMg70=";
    linux-x64 = "sha256-6yJEGeNEV1+qSh85spC2SUJaEM1e4u8dADSAzZrlfrA=";
    linux-x64-musl = "sha256-vMK+kQWHXcMaRIJe3pLkbE+YIl7rOtYXNA2qIXEAM5s=";
  };

  wrapperPath = lib.makeBinPath (
    lib.filter (x: x != null) (
      [ procps ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [ bubblewrap socat ]
    )
  );
in
stdenv.mkDerivation {
  pname = "claude-code";
  inherit version;

  src = fetchurl {
    url = "${releaseBase}/${platform}/claude";
    hash = hashes.${platform} or (throw "No binary hash for ${platform}");
  };

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = [ makeWrapper ]
    ++ lib.optionals stdenv.isLinux (lib.filter (x: x != null) [ autoPatchelfHook ]);

  buildInputs = lib.optionals stdenv.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/libexec/claude-code/claude"

    makeWrapper "$out/libexec/claude-code/claude" "$out/bin/claude" \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --unset DEV \
      --prefix PATH : "${wrapperPath}"
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
  ];
  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR" "$out/bin/claude" --version >/dev/null
    runHook postInstallCheck
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
    homepage = "https://code.claude.com/";
    downloadPage = "https://claude.ai/install.sh";
    license = lib.licenses.unfree;
    mainProgram = "claude";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
