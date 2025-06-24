{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
}:

buildNpmPackage rec {
  pname = "ccmanager";
  version = "0.1.10";

  src = fetchFromGitHub {
    owner = "kbwo";
    repo = "ccmanager";
    rev = "v0.1.10";
    hash = "sha256-ZvQ9vmBaKb73OOeh2qb0FEPkLLEvZ6OJa6yYowzX2fM=";
  };

  npmDepsHash = "sha256-xub1HNanpJ2gVBWS7IZiPu5iq82td3whY1OfZcI5fYA=";

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