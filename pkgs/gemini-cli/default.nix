{ lib
, stdenv
, buildNpmPackage
, fetchFromGitHub
, jq
, makeWrapper
, nodejs_22
, pkg-config
, libsecret
, ripgrep
, nix-update-script
, clang_20 ? null
, # Optional, only for Darwin
}:

buildNpmPackage (finalAttrs: {
  pname = "gemini-cli";
  version = "0.39.1";
  nodejs = nodejs_22;

  src = fetchFromGitHub {
    owner = "google-gemini";
    repo = "gemini-cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-O0TBrT3WDCBZ3ZyFyJPBBtPfnDzdFQ7b8pOJOD7bj2g=";
  };

  npmDepsHash = "sha256-y0LafX1+ukW8HRYBqQ3QfZGHo1cVk00bNygdwsBR/7g=";

  nativeBuildInputs = [
    jq
    makeWrapper
    pkg-config
  ]
  ++ lib.optionals stdenv.isDarwin [ clang_20 ];

  buildInputs = [
    ripgrep
    libsecret
  ];

  preConfigure = ''
    mkdir -p packages/generated
    echo "export const GIT_COMMIT_INFO = { commitHash: '${finalAttrs.src.rev}' };" > packages/generated/git-commit.ts
  '';

  postPatch = ''
    # Disable auto-update and update notifications by default.
    sed -i '/enableAutoUpdate: {/,/}/ s/default: true/default: false/' packages/cli/src/config/settingsSchema.ts
    sed -i '/enableAutoUpdateNotification: {/,/}/ s/default: true/default: false/' packages/cli/src/config/settingsSchema.ts
  '';

  preBuild = ''
    npm run build --workspace @google/gemini-cli-devtools
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{bin,share/gemini-cli}

    npm prune --omit=dev
    cp -r node_modules $out/share/gemini-cli/
    
    # Cleanup unnecessary modules
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-core
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-a2a-server
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-devtools
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-sdk
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-test-utils
    rm -f $out/share/gemini-cli/node_modules/gemini-cli-vscode-ide-companion
    
    cp -r packages/cli $out/share/gemini-cli/node_modules/@google/gemini-cli
    cp -r packages/core $out/share/gemini-cli/node_modules/@google/gemini-cli-core
    cp -r packages/a2a-server $out/share/gemini-cli/node_modules/@google/gemini-cli-a2a-server
    cp -r packages/devtools $out/share/gemini-cli/node_modules/@google/gemini-cli-devtools
    cp -r packages/sdk $out/share/gemini-cli/node_modules/@google/gemini-cli-sdk

    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-core/dist/docs/CONTRIBUTING.md

    makeWrapper ${nodejs_22}/bin/node $out/bin/gemini \
      --add-flags "$out/share/gemini-cli/node_modules/@google/gemini-cli/dist/index.js"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "AI agent that brings the power of Gemini directly into your terminal";
    homepage = "https://github.com/google-gemini/gemini-cli";
    license = lib.licenses.asl20;
    mainProgram = "gemini";
    platforms = lib.platforms.all;
  };
})
