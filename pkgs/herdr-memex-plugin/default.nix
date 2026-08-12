{ lib
, stdenv
, fetchFromGitHub
, fetchurl
, autoPatchelfHook
, openssl
, writableTmpDirAsHomeHook
}:

let
  version = "0.9.1";

  # Map Nix systems to memex release assets. / Nix system を memex の release asset に対応付ける。
  sources = {
    x86_64-linux = {
      asset = "memex-0.9.1-linux-x86_64.tar.gz";
      hash = "sha256-zlsMjL5ssGmsm3liwjpvoXjMWCNyEI9+IwbqKZAbvdM=";
    };
    aarch64-linux = {
      asset = "memex-0.9.1-linux-arm64.tar.gz";
      hash = "sha256-pBq7q0gcmDfCC9C5KCQzeuLcddNAevv8U9mNP5YKRuo=";
    };
    x86_64-darwin = {
      asset = "memex-0.9.1-macos-x86_64.tar.gz";
      hash = "sha256-tDLE5DCu+EPKNShBWjY5NqO9DWLfbmZS8fDlh89q6Qw=";
    };
    aarch64-darwin = {
      asset = "memex-0.9.1-macos-arm64.tar.gz";
      hash = "sha256-RRBdDFifGKRr6vzlfTYZCXT4kd9bKpYU216A3xO6Nv4=";
    };
  };

  srcConfig = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "herdr-memex-plugin";
  inherit version;

  src = fetchFromGitHub {
    owner = "nicosuave";
    repo = "memex";
    rev = "v${finalAttrs.version}";
    hash = "sha256-n0C0OSxsCaqVzOQnL7gxYsBwqcux9Q+bgEWaDk2/hYQ=";
  };

  binaryArchive = fetchurl {
    url = "https://github.com/nicosuave/memex/releases/download/v${finalAttrs.version}/${srcConfig.asset}";
    inherit (srcConfig) hash;
  };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    openssl
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;
  # Preserve release signatures on Darwin. / Darwin の release signature を保持する。
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cp -R . "$out/"
    tar -xzf "$binaryArchive" -C "$out/bin" memex
    chmod +x "$out/bin/memex"

    runHook postInstall
  '';

  nativeInstallCheckInputs = [ writableTmpDirAsHomeHook ];
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR" "$out/bin/memex" --version >/dev/null
    HOME="$TMPDIR" "$out/bin/memex" sessions --help >/dev/null
    test -f "$out/herdr-plugin.toml"
    runHook postInstallCheck
  '';

  passthru.pluginId = "nicosuave.memex";

  meta = {
    description = "Herdr session desk for searching and resuming local coding-agent history";
    homepage = "https://github.com/nicosuave/memex";
    changelog = "https://github.com/nicosuave/memex/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "memex";
    platforms = lib.attrNames sources;
  };
})
