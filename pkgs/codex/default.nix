{ lib
, stdenv
, fetchurl
, autoPatchelfHook ? null
, makeWrapper
, openssl ? null
, zlib ? null
, libcap ? null
}:

let
  version = "0.153.4";

  platforms = {
    x86_64-linux = {
      artifact = "codex-x86_64-unknown-linux-musl.tar.gz";
      sha256 = "sha256-9HlCTsoJJITcQNh64oxE9MxAI0pgBF1hMeSTgA2BSjA=";
      hostArtifact = "codex-code-mode-host-x86_64-unknown-linux-musl.tar.gz";
      hostSha256 = "sha256-RTnhBlluIDyfburyD+MoqXUUR9fWVhviWWieoHlfg7A=";
      nativeBuildInputs = lib.filter (x: x != null) [ autoPatchelfHook makeWrapper ];
      buildInputs = lib.filter (x: x != null) [ stdenv.cc.cc.lib openssl zlib libcap ];
    };

    aarch64-linux = {
      artifact = "codex-aarch64-unknown-linux-musl.tar.gz";
      sha256 = "sha256-XNphgr2Uw6MPLrY6SVSJ6/f2kf3bFNcPSMbBpQcbbN4=";
      hostArtifact = "codex-code-mode-host-aarch64-unknown-linux-musl.tar.gz";
      hostSha256 = "sha256-JeIWCBhwbkjFEVUB1ZhvuMPoWsciZ/YZxJRLXhRlzEA=";
      nativeBuildInputs = lib.filter (x: x != null) [ autoPatchelfHook makeWrapper ];
      buildInputs = lib.filter (x: x != null) [ stdenv.cc.cc.lib openssl zlib libcap ];
    };

    x86_64-darwin = {
      artifact = "codex-x86_64-apple-darwin.tar.gz";
      sha256 = "sha256-1pIA8L+EGx0aB/gLgM90Ki5Pwrq5GuikSxBC+OjKn6Q=";
      hostArtifact = "codex-code-mode-host-x86_64-apple-darwin.tar.gz";
      hostSha256 = "sha256-GE2wHxD2oC2t8ka5FEDMFtdaC9tA/0kcSW+IBTiJqSI=";
      nativeBuildInputs = [ makeWrapper ];
    };

    aarch64-darwin = {
      artifact = "codex-aarch64-apple-darwin.tar.gz";
      sha256 = "sha256-jPkR6mdlI7+yEh7FYYSNKrpWSJCtU2202KM1PyuYULE=";
      hostArtifact = "codex-code-mode-host-aarch64-apple-darwin.tar.gz";
      hostSha256 = "sha256-SoeqiaGYl268aKhQF7NiNO3RsSbftj2UwQog/Pq4FHk=";
      nativeBuildInputs = [ makeWrapper ];
    };
  };

  config = platforms.${stdenv.system} or null;

  throwForSystem = throw "No prebuilt Codex binary for ${stdenv.system}.";

  codexUrl = system: artifact:
    "https://github.com/openai/codex/releases/download/rust-v${version}/${artifact}";
in
if config == null then
  throwForSystem
else
  let
    binaryName = lib.removeSuffix ".tar.gz" config.artifact;
    hostBinaryName = lib.removeSuffix ".tar.gz" config.hostArtifact;
  in
  stdenv.mkDerivation rec {
    pname = "codex";
    inherit version;

    srcs = [
      (fetchurl {
        url = codexUrl stdenv.system config.artifact;
        sha256 = config.sha256;
      })
      # codex looks up codex-code-mode-host next to its own executable
      (fetchurl {
        url = codexUrl stdenv.system config.hostArtifact;
        sha256 = config.hostSha256;
      })
    ];

    nativeBuildInputs = config.nativeBuildInputs;
    buildInputs = config.buildInputs or [ ];

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack
      for srcFile in $srcs; do
        tar -xzf "$srcFile"
      done
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 "${binaryName}" "$out/bin/codex"
      install -Dm755 "${hostBinaryName}" "$out/bin/codex-code-mode-host"
      runHook postInstall
    '';

    postInstall = ''
            if [ -x "$out/bin/codex" ]; then
              mv "$out/bin/codex" "$out/bin/.codex-real"
              cat > "$out/bin/codex" <<'EOF'
      #!${stdenv.shell}
      set -eo pipefail

      binary="@codex_real@"

      skip_default_dangerous=0
      if [ -n "$CODEX_SKIP_DEFAULT_DANGEROUS" ] && [ "$CODEX_SKIP_DEFAULT_DANGEROUS" != "0" ]; then
        skip_default_dangerous=1
      fi

      if [ "$skip_default_dangerous" -eq 0 ]; then
        need_dangerous_flag=1
        prev=""
        for arg in "$@"; do
          case "$prev" in
            -s|--sandbox|-a|--ask-for-approval)
              need_dangerous_flag=0
              break
              ;;
          esac

          case "$arg" in
            --dangerously-bypass-approvals-and-sandbox|--full-auto|-s|-s=*|--sandbox|--sandbox=*|-a|-a=*|--ask-for-approval|--ask-for-approval=*)
              need_dangerous_flag=0
              break
              ;;
          esac

          prev="$arg"
        done

        if [ "$need_dangerous_flag" -eq 1 ]; then
          set -- --dangerously-bypass-approvals-and-sandbox "$@"
        fi
      fi

      need_no_alt_screen=1
      if [ -n "$CODEX_SKIP_DEFAULT_NO_ALT_SCREEN" ] && [ "$CODEX_SKIP_DEFAULT_NO_ALT_SCREEN" != "0" ]; then
        need_no_alt_screen=0
      fi

      for arg in "$@"; do
        case "$arg" in
          --no-alt-screen)
            need_no_alt_screen=0
            break
            ;;
        esac
      done

      if [ "$need_no_alt_screen" -eq 1 ]; then
        set -- --no-alt-screen "$@"
      fi

      ${if stdenv.hostPlatform.isLinux then ''
        exec ${libcap}/bin/capsh \
          --noamb \
          --inh= \
          --caps= \
          --shell=${stdenv.shell} \
          -- -c 'exec -a "$0" "$@"' "$0" "$binary" "$@"
      '' else ''
        exec -a "$0" "$binary" "$@"
      ''}
      EOF
              substituteInPlace "$out/bin/codex" --replace "@codex_real@" "$out/bin/.codex-real"
              chmod 755 "$out/bin/codex"
            fi
    '';

    meta = {
      description = "Command line interface for OpenAI Codex";
      longDescription = "Prebuilt Codex CLI with sandbox override wrapper.";
      homepage = "https://github.com/openai/codex";
      license = lib.licenses.asl20;
      maintainers = with lib.maintainers; [ ];
      platforms = lib.attrNames platforms;
    };
  }
