{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
}:

buildNpmPackage rec {
  pname = "ccmanager";
  version = "2.0.0";

  src = fetchFromGitHub {
    owner = "kbwo";
    repo = "ccmanager";
    rev = "v2.0.0";
    hash = "sha256-EVKo5UjGcFYGvGkRsKUydIBGnggTWqXuOtKAJTh5hZg=";
  };

  npmDepsHash = "sha256-G2DjuFFUqBHKRFAX5uZzBWztfRKj7njZDmjJBf1xj1w=";

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