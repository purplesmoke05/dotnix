{ lib
, stdenv
, buildDotnetModule
, dotnetCorePackages
, fetchFromGitHub
, buildNpmPackage
, esbuild
, python3
, chromium
, writeShellScript
, coreutils
, darwinBrowser ? "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
}:

let
  browser = writeShellScript "officecli-chromium" ''
    set -euo pipefail
    officecli_browser_profile=$(${lib.getExe' coreutils "mktemp"} -d "''${TMPDIR:-/tmp}/officecli-browser.XXXXXX")
    trap '${lib.getExe' coreutils "rm"} -rf -- "$officecli_browser_profile"' EXIT
    ${if stdenv.hostPlatform.isDarwin then lib.escapeShellArg darwinBrowser else lib.getExe chromium} \
      --user-data-dir="$officecli_browser_profile" \
      --no-first-run --no-default-browser-check --disable-background-networking "$@"
  '';

  browserAssets = buildNpmPackage {
    pname = "officecli-browser-assets";
    version = "1.0.153";
    src = lib.fileset.toSource {
      root = ./assets;
      fileset = lib.fileset.unions [
        ./assets/package.json
        ./assets/package-lock.json
        ./assets/build.mjs
        ./assets/src
      ];
    };
    npmDepsHash = "sha256-ikrzPAqJ3OKuzfGNGJxLnCbrqXyEvHm8Qbc7n+8uRao=";
    npmInstallFlags = [ "--ignore-scripts" ];
    nativeBuildInputs = [ esbuild ];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r dist/. "$out/"
      runHook postInstall
    '';
  };
in
buildDotnetModule (finalAttrs: {
  pname = "officecli";
  version = "1.0.153";

  src = fetchFromGitHub {
    owner = "iOfficeAI";
    repo = "OfficeCLI";
    rev = "97576af891a3b5d9c81c57d4f420113968abfee5";
    hash = "sha256-1pvgR+BViuu3cuLEiEMprZThh2/W2OmDGi2rcMg7HUQ=";
  };

  patches = [
    ./preview-safety.patch
    ./browser-assets.patch
  ];

  projectFile = "src/officecli/officecli.csproj";
  nugetDeps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_10_0;
  dotnet-runtime = dotnetCorePackages.runtime_10_0;
  selfContainedBuild = true;
  executables = [ "officecli" ];
  strictDeps = true;
  __structuredAttrs = true;

  postPatch = ''
    cp -r ${browserAssets} src/officecli/Resources/browser-assets
    substituteInPlace src/officecli/officecli.csproj \
      --replace-fail '</Project>' '<ItemGroup><EmbeddedResource Include="Resources/browser-assets/*.js;Resources/browser-assets/*.css" LogicalName="OfficeCli.Resources.browser-assets.%(Filename)%(Extension)" /></ItemGroup></Project>'
  '';

  makeWrapperArgs = [
    "--set"
    "OFFICECLI_SKIP_UPDATE"
    "1"
    "--set"
    "OFFICECLI_NO_AUTO_INSTALL"
    "1"
    "--set"
    "OFFICECLI_NO_AUTO_RESIDENT"
    "1"
    "--set"
    "OFFICECLI_BROWSER"
    "${browser}"
  ];

  postInstall = ''
    install -Dm644 LICENSE "$out/share/licenses/officecli/LICENSE"
    install -m644 NOTICE THIRD-PARTY-NOTICES.txt "$out/share/licenses/officecli/"
    cp -r ${browserAssets}/LICENSES "$out/share/licenses/officecli/browser-assets"
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ python3 ];
  installCheckPhase = ''
    runHook preInstallCheck
    ${lib.getExe python3} ${./test-security.py} "$out/bin/officecli"
    runHook postInstallCheck
  '';

  passthru = { inherit browserAssets; };

  meta = {
    description = "Office document CLI with fixed local preview assets";
    homepage = "https://github.com/iOfficeAI/OfficeCLI";
    changelog = "https://github.com/iOfficeAI/OfficeCLI/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "officecli";
    platforms = finalAttrs.dotnet-sdk.meta.platforms;
    sourceProvenance = with lib.sourceTypes; [ fromSource binaryBytecode ];
  };
})
