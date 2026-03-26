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
  version = "2.1.76";
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
    darwin-arm64 = "sha256-/+ki9PSsVC9O2+6rvOKnSSMI0DTGaiQnyuxcMcObccg=";
    darwin-x64 = "sha256-KhPZo8oP4zD9eGNBiXry5SUAZru7H9y2z9/6UM8PkP4=";
    linux-arm64 = "sha256-QPdTwH8HDfNMqD5AD3Rqgnmj/TQ5Z6RT2fv6svPKes0=";
    linux-arm64-musl = "sha256-GPueI2FJvUddnFuewDP1yT0t7A3KH3s0zslv1CN5SXw=";
    linux-x64 = "sha256-gBoIVnbD1UOSxC6OQ8RJR998UhMjVldffZJnxPItaZI=";
    linux-x64-musl = "sha256-8XrQ/lRIeZzap65f13Ey4AA5QhldqRVGpPXnsve/LwU=";
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
