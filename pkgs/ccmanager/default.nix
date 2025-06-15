{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
}:

buildNpmPackage rec {
  pname = "ccmanager";
  version = "0.1.2";

  src = fetchFromGitHub {
    owner = "kbwo";
    repo = "ccmanager";
    rev = "${version}";
    hash = "sha256-JYD0Ft0PhDN2Yauh6+pHwXoiYo+p9KCq3kWKFTtu8Xk=";
  };

  npmDepsHash = "sha256-iutcS6950cy8Op+LKdby90sEEtNaGLGb+MgxjV+c1Kg=";

  # Build configuration
  npmBuildScript = "build";
  
  # Let buildNpmPackage handle installation automatically
  dontNpmInstall = false;

  meta = with lib; {
    description = "TUI application for managing multiple Claude Code sessions across Git worktrees";
    homepage = "https://github.com/kbwo/ccmanager";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = platforms.all;
  };
}