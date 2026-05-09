{ lib
, stdenvNoCC
, buildGo126Module
, fetchFromGitHub
, fetchPnpmDeps
, nodejs_24
, pnpm_10
, pnpmConfigHook
,
}:

let
  pname = "sub2api";
  version = "0.1.125";

  src = fetchFromGitHub {
    owner = "Wei-Shaw";
    repo = "sub2api";
    tag = "v${version}";
    hash = "sha256-V6BJXLk3T4m3Wa1G2V+f6kuCavZbVA3toCHsslxbSLA=";
  };

  frontend = stdenvNoCC.mkDerivation {
    pname = "${pname}-frontend";
    inherit src version;

    sourceRoot = "${src.name}/frontend";

    nativeBuildInputs = [
      nodejs_24
      pnpmConfigHook
      pnpm_10
    ];

    pnpmDeps = fetchPnpmDeps {
      inherit
        src
        version
        ;
      pname = "${pname}-frontend";
      sourceRoot = "${src.name}/frontend";
      pnpm = pnpm_10;
      fetcherVersion = 3;
      hash = "sha256-1WXc/ukN6QyCrUCxvvMbD6LjuWeMG2a6vBoHx8TWKU0=";
    };

    postPatch = ''
      chmod -R u+w ../backend
    '';

    buildPhase = ''
      runHook preBuild
      pnpm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -r ../backend/internal/web/dist "$out"
      runHook postInstall
    '';
  };
in
buildGo126Module {
  inherit pname src version;

  sourceRoot = "${src.name}/backend";
  vendorHash = "sha256-LROy5Qe31AH64yk8aDjZMTmbA0/TJNsBmqTNwJ0y4eA=";

  postPatch = ''
    go mod edit \
      -droprequire=github.com/google/subcommands \
      -require=github.com/aws/aws-sdk-go-v2@v1.41.5 \
      -require=go.opentelemetry.io/otel@v1.41.0 \
      -require=go.opentelemetry.io/otel/metric@v1.41.0 \
      -require=go.opentelemetry.io/otel/sdk@v1.41.0 \
      -require=go.opentelemetry.io/otel/trace@v1.41.0 \
      -require=go.opentelemetry.io/auto/sdk@v1.2.1 \
      -require=github.com/aws/aws-sdk-go-v2/aws/protocol/eventstream@v1.7.8 \
      -require=github.com/aws/aws-sdk-go-v2/internal/configsources@v1.4.21 \
      -require=github.com/aws/aws-sdk-go-v2/internal/endpoints/v2@v2.7.21 \
      -require=github.com/aws/aws-sdk-go-v2/internal/v4a@v1.4.22 \
      -require=github.com/aws/aws-sdk-go-v2/service/internal/accept-encoding@v1.13.7 \
      -require=github.com/aws/aws-sdk-go-v2/service/internal/checksum@v1.9.13 \
      -require=github.com/aws/aws-sdk-go-v2/service/internal/presigned-url@v1.13.21 \
      -require=github.com/aws/aws-sdk-go-v2/service/internal/s3shared@v1.19.21 \
      -require=github.com/aws/aws-sdk-go-v2/service/s3@v1.97.3
  '';

  preBuild = ''
    if [[ "''${name:-}" == *-go-modules ]]; then
      go mod tidy
    else
      rm -rf internal/web/dist
      cp -r ${frontend} internal/web/dist
    fi
  '';

  subPackages = [ "cmd/server" ];
  tags = [ "embed" ];
  env.CGO_ENABLED = "0";

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
    "-X main.Commit=8a835b22bb9d629126127e8d2a42d9fc60928ff2"
    "-X main.Date=2026-05-07T11:26:18Z"
    "-X main.BuildType=release"
  ];

  postInstall = ''
    mv "$out/bin/server" "$out/bin/sub2api"
    mkdir -p "$out/share/sub2api"
    cp -r resources "$out/share/sub2api/resources"
  '';

  doCheck = false;

  meta = {
    description = "AI API Gateway Platform";
    homepage = "https://github.com/Wei-Shaw/sub2api";
    license = lib.licenses.mit;
    mainProgram = "sub2api";
    platforms = lib.platforms.linux;
  };
}
