{ lib
, stdenv
, fetchurl
, makeBinaryWrapper
, autoPatchelfHook
, writableTmpDirAsHomeHook
}:

let
  version = "0.21.1";

  # Map Nix systems to Hunk release assets. / Nix system を Hunk の release asset に対応付ける。
  sources = {
    x86_64-linux = {
      asset = "hunkdiff-linux-x64.tar.gz";
      hash = "sha256-x9HiO6T/tsozMHl+nwyC262lDjz+G3GfQZR0fyy8oSI=";
    };
    aarch64-linux = {
      asset = "hunkdiff-linux-arm64.tar.gz";
      hash = "sha256-HTHfw4K5pN+cBF6yOewkj2HEFh3TLsfKqrhZPVWp7KY=";
    };
    x86_64-darwin = {
      asset = "hunkdiff-darwin-x64.tar.gz";
      hash = "sha256-kMLcftiHkIu1WG3J7JBqDhWw5TpDxZWWjoaGO2KtSWw=";
    };
    aarch64-darwin = {
      asset = "hunkdiff-darwin-arm64.tar.gz";
      hash = "sha256-x42IH/PmgljKa+faINeG7cBZk6U1zFu6LkopjdwYAbo=";
    };
  };

  srcConfig = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "hunk";
  inherit version;

  src = fetchurl {
    url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/${srcConfig.asset}";
    inherit (srcConfig) hash;
  };

  # Let unpackPhase detect the tarball's single top-level directory. / tarball 内の単一 top-level directory は unpackPhase に自動検出させる。

  nativeBuildInputs = [ makeBinaryWrapper ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # Keep the binary and bundled skills together because Hunk resolves them from the executable path. / Hunk は実行ファイルの path から bundled skills を解決するため、同じ directory に配置する。
    install -Dm755 hunk $out/libexec/hunk/hunk
    cp -r skills $out/libexec/hunk/
    cp metadata.json $out/libexec/hunk/

    # Preserve the real executable path through the wrapper so `hunk skill path` resolves correctly. / wrapper 経由でも実行ファイルの path を保持し、`hunk skill path` を正しく解決する。
    makeBinaryWrapper $out/libexec/hunk/hunk $out/bin/hunk
    ln -s hunk $out/bin/hunkdiff

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ writableTmpDirAsHomeHook ];
  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR" "$out/bin/hunk" --version >/dev/null
    skill_path="$(HOME="$TMPDIR" "$out/bin/hunk" skill path)"
    test -f "$skill_path"
    runHook postInstallCheck
  '';

  meta = {
    description = "Review-first terminal diff viewer for agent-authored changesets";
    homepage = "https://github.com/modem-dev/hunk";
    changelog = "https://github.com/modem-dev/hunk/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "hunk";
    platforms = lib.attrNames sources;
  };
})
