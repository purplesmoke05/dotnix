{ lib
, stdenv
, rustPlatform
, fetchFromGitHub
, fetchPnpmDeps
, applyPatches
, cargo-tauri
, nodejs
, pnpm_10
, pnpmConfigHook
, pkg-config
, wrapGAppsHook3
, openssl
, webkitgtk_4_1
, glib-networking
, libappindicator-gtk3
,
}:

let
  pnpm = pnpm_10;
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "cc-switch";
  version = "3.14.1";

  src = applyPatches {
    src = fetchFromGitHub {
      owner = "farion1231";
      repo = "cc-switch";
      tag = "v${finalAttrs.version}";
      hash = "sha256-mSTuPTACW4yiR9e43Kp3RcbitbZ3OQUdZsHwZlSn6iQ=";
    };
    patches = [
      ./nix-managed.patch
    ];
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      ;
    inherit pnpm;
    fetcherVersion = 3;
    hash = "sha256-O9XaKDFajYr966/tAUmhQ8S5/8ifW2YXxpiFqJMdWP8=";
  };

  cargoRoot = "src-tauri";
  cargoHash = "sha256-enluQjaF/LyC9eHlWF7akphh32H5Fqqvy0IcSkImOE0=";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  postPatch = ''
    substituteInPlace src/i18n/index.ts \
      --replace 'const DEFAULT_LANGUAGE: Language = "zh";' 'const DEFAULT_LANGUAGE: Language = "ja";'

    substituteInPlace src/hooks/useSettingsForm.ts \
      --replace 'if (!lang) return "zh";' 'if (!lang) return "ja";' \
      --replace 'const initialLanguageRef = useRef<Language>("zh");' 'const initialLanguageRef = useRef<Language>("ja");'
  '';

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    cargo-tauri.hook
    pkg-config
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ wrapGAppsHook3 ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    openssl
    webkitgtk_4_1
    glib-networking
    libappindicator-gtk3
  ];

  preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libappindicator-gtk3 ]}"
    )
  '';

  # Upstream tests exercise desktop integration outside the Nix build sandbox. / 上流テストは Nix ビルドサンドボックス外のデスクトップ連携を扱う。
  doCheck = false;

  meta = {
    description = "Desktop GUI for switching Claude Code API providers and profiles";
    homepage = "https://github.com/farion1231/cc-switch";
    changelog = "https://github.com/farion1231/cc-switch/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "cc-switch";
    platforms = lib.platforms.linux;
  };
})
