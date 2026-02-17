{ lib
, stdenv
, buildNpmPackage
, fetchzip
, versionCheckHook
, writableTmpDirAsHomeHook
, bubblewrap
, procps
, socat
}:
buildNpmPackage (finalAttrs: {
  pname = "claude-code";
  version = "2.1.39";

  src = fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${finalAttrs.version}.tgz";
    hash = "sha256-NLLiaJkU91ZnEcQUWIAX9oUTt+C5fnWXFFPelTtWmdo=";
  };

  npmDepsHash = "sha256-VWw1bYkFch95JDlOwKoTAQYOr8R80ICJ8QUI4E64W7o=";

  strictDeps = true;

  postPatch = ''
    cp ${./package-lock.json} package-lock.json

    substituteInPlace cli.js \
      --replace-fail '#!/bin/sh' '#!/usr/bin/env sh'
  '';

  dontNpmBuild = true;

  env.AUTHORIZED = "1";

  postInstall = ''
    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --unset DEV \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            procps
          ]
          ++ lib.optionals stdenv.hostPlatform.isLinux [
            bubblewrap
            socat
          ]
        )
      }
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
    homepage = "https://github.com/anthropics/claude-code";
    downloadPage = "https://www.npmjs.com/package/@anthropic-ai/claude-code";
    license = lib.licenses.unfree;
    mainProgram = "claude";
  };
})
