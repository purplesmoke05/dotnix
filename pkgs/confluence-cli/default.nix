{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs_22
, stdenv
, writableTmpDirAsHomeHook
}:

buildNpmPackage rec {
  pname = "confluence-cli";
  version = "1.27.6";
  nodejs = nodejs_22;

  src = fetchFromGitHub {
    owner = "pchuri";
    repo = "confluence-cli";
    rev = "v${version}";
    hash = "sha256-TznnYZl0l0Z3wegrZ+e6ceK1fFN5B6RLHtkB+xHUJCk=";
  };

  npmDepsHash = "sha256-19JlVbW2c1U16tgk6w7f5NJTVpkpYE2zaIUUGHaElSs=";

  dontNpmBuild = true;

  postInstall = ''
        for program in confluence confluence-cli; do
          mv "$out/bin/$program" "$out/bin/.$program-real"
          cat > "$out/bin/$program" <<'EOF'
    #!${stdenv.shell}
    if [ -z "''${CONFLUENCE_READ_ONLY+x}" ]; then
      export CONFLUENCE_READ_ONLY=true
    fi
    exec "@real_program@" "$@"
    EOF
          substituteInPlace "$out/bin/$program" --replace-fail "@real_program@" "$out/bin/.$program-real"
          chmod 755 "$out/bin/$program"
        done
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
  ];
  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR" "$out/bin/confluence" --help >/dev/null
    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "Command-line interface for Atlassian Confluence";
    homepage = "https://github.com/pchuri/confluence-cli";
    license = licenses.mit;
    mainProgram = "confluence";
    platforms = platforms.all;
  };
}
