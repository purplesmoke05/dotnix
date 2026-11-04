{ lib
, stdenvNoCC
, fetchFromGitHub
, fetchurl
}:

let
  version = "0.1.24";

  # Map Nix systems to Herdr Plus release assets. / Nix system を Herdr Plus の release asset に対応付ける。
  sources = {
    x86_64-linux = {
      asset = "herdr-plus_${version}_linux_amd64.tar.gz";
      hash = "sha256-0fNz6s7xnxy4xLU4Eftin6lgBJ22qAxcOCn1R4XF0tg=";
    };
    aarch64-linux = {
      asset = "herdr-plus_${version}_linux_arm64.tar.gz";
      hash = "sha256-gipsFvo4OnLGIXkkHV76w2DlGo8NxNcqIgz1HpQaIDQ=";
    };
    x86_64-darwin = {
      asset = "herdr-plus_${version}_darwin_amd64.tar.gz";
      hash = "sha256-4adsBJdp846S5CnNOLy4ahvsR9/u+qr5uqNHfJCHQDM=";
    };
    aarch64-darwin = {
      asset = "herdr-plus_${version}_darwin_arm64.tar.gz";
      hash = "sha256-wj8Magdqe56/4kr+yemjXCAHGAaTnZRBq/cHC6HRbYA=";
    };
  };

  srcConfig = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-plus-plugin";
  inherit version;

  src = fetchFromGitHub {
    owner = "cloudmanic";
    repo = "herdr-plus";
    rev = "v${finalAttrs.version}";
    hash = "sha256-2NnPlZSPBoZa22A02q/FQLm1a7+FH/tCzALZSpP5rkQ=";
  };

  binaryArchive = fetchurl {
    url = "https://github.com/cloudmanic/herdr-plus/releases/download/v${finalAttrs.version}/${srcConfig.asset}";
    inherit (srcConfig) hash;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cp -R . "$out/"
    tar -xzf "$binaryArchive" -C "$out/bin" herdr-plus
    chmod +x "$out/bin/herdr-plus"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/herdr-plus" version >/dev/null
    test -f "$out/herdr-plugin.toml"
    runHook postInstallCheck
  '';

  passthru.pluginId = "cloudmanic.herdr-plus";

  meta = {
    description = "Herdr workspace templates and quick actions";
    homepage = "https://github.com/cloudmanic/herdr-plus";
    changelog = "https://github.com/cloudmanic/herdr-plus/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "herdr-plus";
    platforms = lib.attrNames sources;
  };
})
