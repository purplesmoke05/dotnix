{ lib
, stdenvNoCC
, fetchFromGitHub
, fetchurl
}:

let
  version = "0.30.1";

  # Map Nix systems to reviewr release assets. / Nix system を reviewr の release asset に対応付ける。
  sources = {
    x86_64-linux = {
      asset = "herdr-reviewr-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-TAIzZeDIymem8uSmJWrxxJqRanqFPpRSbt93qXrn8hM=";
    };
    aarch64-linux = {
      asset = "herdr-reviewr-aarch64-unknown-linux-musl.tar.gz";
      hash = "sha256-3Af//Iz3aDtQrWaWz5OKCe0dlWKnlDu/TtjYPZnP014=";
    };
    x86_64-darwin = {
      asset = "herdr-reviewr-x86_64-apple-darwin.tar.gz";
      hash = "sha256-XYct2w6pYDO6gGhBH8L++XMpArpFeARWNdbTcKHPXfU=";
    };
    aarch64-darwin = {
      asset = "herdr-reviewr-aarch64-apple-darwin.tar.gz";
      hash = "sha256-FDJ4zVgY1EPq0eKsiyF8UpK26L8X7JAG3b8aUcklygQ=";
    };
  };

  srcConfig = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-reviewr-plugin";
  inherit version;

  src = fetchFromGitHub {
    owner = "persiyanov";
    repo = "herdr-reviewr";
    rev = "v${finalAttrs.version}";
    hash = "sha256-U+h5iMtkSslElRpcohGzVK1xbfsepJV9vNPO05IRwag=";
  };

  binaryArchive = fetchurl {
    url = "https://github.com/persiyanov/herdr-reviewr/releases/download/v${finalAttrs.version}/${srcConfig.asset}";
    inherit (srcConfig) hash;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cp -R . "$out/"
    tar -xzf "$binaryArchive" -C "$out/bin"
    chmod +x "$out/bin/herdr-reviewr"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x "$out/bin/herdr-reviewr"
    test -f "$out/herdr-plugin.toml"
    runHook postInstallCheck
  '';

  passthru.pluginId = "persiyanov.reviewr";

  meta = {
    description = "Herdr pane for reviewing agent-authored diffs and returning line comments";
    homepage = "https://github.com/persiyanov/herdr-reviewr";
    changelog = "https://github.com/persiyanov/herdr-reviewr/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "herdr-reviewr";
    platforms = lib.attrNames sources;
  };
})
