{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, installShellFiles
}:

let
  version = "0.9.17";

  sources = {
    x86_64-linux = {
      url = "https://github.com/astral-sh/uv/releases/download/${version}/uv-x86_64-unknown-linux-gnu.tar.gz";
      hash = "sha256-ARTVT5qv0HUWzxyt/nKvqXD1/Sk/voLdkkuKe0LJhNg=";
    };
    aarch64-linux = {
      url = "https://github.com/astral-sh/uv/releases/download/${version}/uv-aarch64-unknown-linux-gnu.tar.gz";
      hash = "sha256-6eupe3Fp5H/TySbkCfC3FIIPC+/COzrgYngFhqeT5Mw=";
    };
    x86_64-darwin = {
      url = "https://github.com/astral-sh/uv/releases/download/${version}/uv-x86_64-apple-darwin.tar.gz";
      hash = "sha256-JJ5/sY1FwGuig8SPCo5Ybsxfu56NrQkjxBaafE24FbI=";
    };
    aarch64-darwin = {
      url = "https://github.com/astral-sh/uv/releases/download/${version}/uv-aarch64-apple-darwin.tar.gz";
      hash = "sha256-oeFGSqHQTV5fpwCqLy4QOX0RFOg129Vr4lumXJoxvZk=";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation rec {
  pname = "uv";
  inherit version;

  src = fetchurl {
    inherit (source) url hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = [ installShellFiles ]
    ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.isLinux [
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall
    
    install -Dm755 */uv $out/bin/uv
    install -Dm755 */uvx $out/bin/uvx

    # Manually patch on Linux so we can run the binary for completion generation
    ${lib.optionalString stdenv.isLinux "autoPatchelf $out"}
    
    # Generate shell completions
    $out/bin/uv generate-shell-completion bash > uv.bash
    $out/bin/uv generate-shell-completion fish > uv.fish
    $out/bin/uv generate-shell-completion zsh > uv.zsh
    
    installShellCompletion --cmd uv \
      --bash uv.bash \
      --fish uv.fish \
      --zsh uv.zsh
      
    runHook postInstall
  '';

  meta = with lib; {
    description = "An extremely fast Python package installer and resolver, written in Rust";
    homepage = "https://github.com/astral-sh/uv";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = builtins.attrNames sources;
    mainProgram = "uv";
  };
}
