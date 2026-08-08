{ lib
, stdenv
, rustPlatform
, fetchFromGitHub
, makeWrapper
, google-chrome
, xvfb
, fontconfig
}:

rustPlatform.buildRustPackage rec {
  pname = "bladebro";
  version = "3.0.26";

  src = fetchFromGitHub {
    owner = "dondai44423";
    repo = "bladebro";
    rev = "794b5a09df9b9643cee00b253a475fac22e9a65c";
    hash = "sha256-AgUo16/PA1KeMnCv5e54hjt1HWNXrQOeXA6BFJzjEVw=";
  };

  cargoHash = "sha256-owFk+ppcZgMW1tPkSVBUKZj6WQMIhjHb/6YxagJAtUc=";

  patches = [
    ./harden-defaults.patch
  ];

  # Preserve pinned commit provenance in release tarball builds. / リリース tarball ビルドでも固定コミットの由来を保持する。
  postPatch = ''
    substituteInPlace build.rs \
      --replace-fail '.unwrap_or_else(|| "unknown".into());' \
      '.unwrap_or_else(|| "794b5a0".into());'
  '';

  nativeBuildInputs = [
    makeWrapper
  ];

  preCheck = ''
    export HOME="$TMPDIR"
  '';

  postInstall = ''
    mkdir -p "$out/share/pi/extensions"
    cp npm/bladebro/pi-extension.ts "$out/share/pi/extensions/bladebro.ts"
    substituteInPlace "$out/share/pi/extensions/bladebro.ts" \
      --replace-fail "binaryPath = resolveBinary();" 'binaryPath = "bladebro";'

    wrapper_args=(
      --set CHROME_PATH ${lib.getExe google-chrome}
      --set BLADE_NO_UPDATE_CHECK 1
    )
    ${lib.optionalString stdenv.isLinux ''
      # Provide an invisible headful display and font discovery on Linux. / Linux では不可視の headful display とフォント検出を提供する。
      wrapper_args+=(--prefix PATH : ${lib.makeBinPath [ xvfb fontconfig ]})
    ''}
    wrapProgram "$out/bin/bladebro" "''${wrapper_args[@]}"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/bladebro" --version >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Agentic browser driver for AI coding agents";
    homepage = "https://github.com/dondai44423/bladebro";
    changelog = "https://github.com/dondai44423/bladebro/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "bladebro";
    platforms = google-chrome.meta.platforms;
  };
}
