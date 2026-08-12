{ lib
, stdenvNoCC
, fetchFromGitHub
, fetchurl
}:

let
  version = "0.1.20";

  # Map Nix systems to Herdr Plus release assets. / Nix system を Herdr Plus の release asset に対応付ける。
  sources = {
    x86_64-linux = {
      asset = "herdr-plus_0.1.20_linux_amd64.tar.gz";
      hash = "sha256-ic4zGjDwmgwEofwNoLNzISKDgZqszKl3zl5UrZmuM48=";
    };
    aarch64-linux = {
      asset = "herdr-plus_0.1.20_linux_arm64.tar.gz";
      hash = "sha256-/Kmy+ei1+BEY30E95dUEFPForge6jbd0acIGOLXIk1I=";
    };
    x86_64-darwin = {
      asset = "herdr-plus_0.1.20_darwin_amd64.tar.gz";
      hash = "sha256-KYyAg/PRWmiS6kM/g5nJT+vq2qsZQ3XxcTpYedrcYDY=";
    };
    aarch64-darwin = {
      asset = "herdr-plus_0.1.20_darwin_arm64.tar.gz";
      hash = "sha256-0rB6eCKTZzj4uOarv+35oceiyH2802YemGeBf1lzh0s=";
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
    hash = "sha256-W95USA0EwP5Oml3qb/wkPqRn+yaaevNBhQuyl9pqaxY=";
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
