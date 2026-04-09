{ lib
, buildNpmPackage
, fetchFromGitHub
, makeWrapper
, nodejs_22
, writableTmpDirAsHomeHook
}:

buildNpmPackage rec {
  pname = "m365";
  version = "11.6.0";
  nodejs = nodejs_22;

  src = fetchFromGitHub {
    owner = "pnp";
    repo = "cli-microsoft365";
    rev = "v${version}";
    hash = "sha256-SrZq6i+q5hBAHDoYcG1/KUoQTO6IuM+wUpswFKI0r34=";
  };

  npmDepsHash = "sha256-Xr0RaEHZ1qsq98nbifMfEeHYccTCtOAZKxuK7bidITc=";
  npmBuildScript = "build";

  nativeBuildInputs = [
    makeWrapper
  ];

  postInstall = ''
    for program in m365 microsoft365 m365_comp m365_chili; do
      wrapProgram "$out/bin/$program" \
        --set-default CLIMICROSOFT365_NOUPDATE 1
    done
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
  ];
  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR" "$out/bin/m365" --help >/dev/null
    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "CLI for Microsoft 365";
    homepage = "https://github.com/pnp/cli-microsoft365";
    license = licenses.mit;
    mainProgram = "m365";
    platforms = platforms.all;
  };
}
