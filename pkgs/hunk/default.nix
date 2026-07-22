{ lib
, stdenv
, fetchurl
, makeBinaryWrapper
, autoPatchelfHook
, writableTmpDirAsHomeHook
}:

let
  version = "0.17.3";

  # Map Nix systems to Hunk release assets. / Nix system を Hunk の release asset に対応付ける。
  sources = {
    x86_64-linux = {
      asset = "hunkdiff-linux-x64.tar.gz";
      hash = "sha256-bhkuQjZagfIIPxahwXbNGOkqAW8NmBtgY3zQKyzQcG0=";
    };
    aarch64-linux = {
      asset = "hunkdiff-linux-arm64.tar.gz";
      hash = "sha256-tbtOIZy9XhPzTDTvjOBs4kZ+L58wN+Jg8Q7LVjpnum0=";
    };
    x86_64-darwin = {
      asset = "hunkdiff-darwin-x64.tar.gz";
      hash = "sha256-7PTbNjV8sx4Iqq0VqNB1MVB9eHF8/wHfh7MB48Lwe1c=";
    };
    aarch64-darwin = {
      asset = "hunkdiff-darwin-arm64.tar.gz";
      hash = "sha256-e/b86d/ma1kifCrc+WeBzcpooQlEGCqYcjVK427+NrA=";
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
