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
  version = "2.1.119";
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
    darwin-arm64 = "sha256-Mds0RDCdXQ+Lheh4Li3NhvMffkjBoeg9abCSaMe0+aI=";
    darwin-x64 = "sha256-UrO3XP6AxiaYKy/7Omzhx5eCTyV9wnXPCjwywgK2o98=";
    linux-arm64 = "sha256-OCqnPqSwf9jWmOMVm1754bhzn651BbqN3Si4pqYoGc4=";
    linux-arm64-musl = "sha256-4Jv67di/3q6+Xxz5u4Hr63GDEsaP/843n7UXhiYxQ9A=";
    linux-x64 = "sha256-zKQwU/BilJSVWWsRtv0bWc95ECrbE7rL5mmX5vrkHko=";
    linux-x64-musl = "sha256-70GhFlOznBTbLTQ/H14qOvfrmHHGPmTetuZZGWcKTgs=";
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
