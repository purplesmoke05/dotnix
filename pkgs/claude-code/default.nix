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
  version = "2.1.116";
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
    darwin-arm64 = "sha256-Ts+1tcMFhdCj1bXvgCo5gE3cM6YwEu4NSu5NTj20brQ=";
    darwin-x64 = "sha256-RYbQwXdyqCbQ1X5GZLZv+6IaAdEahhGlVmtYe/JMNAo=";
    linux-arm64 = "sha256-3DhUwnGlMj2pBH+QxbGlvfeKwDR060XJwmuE7PnyE0w=";
    linux-arm64-musl = "sha256-5+1UqdxqpM4raejE65CDi8+BSp7lCsKfk/D4DokKUAk=";
    linux-x64 = "sha256-DRrqXOBWpc5JHafpu+Y/mSWF5cJIUvAjoHyPGM8pLMU=";
    linux-x64-musl = "sha256-JpGdYhvuCf2nU1ZMpcy1lO3B51OpCS5h3scVYqS39lw=";
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
    install -Dm755 "$src" "$out/bin/.claude-real"

    makeWrapper "$out/bin/.claude-real" "$out/bin/claude" \
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
