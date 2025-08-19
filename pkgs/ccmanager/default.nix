{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
}:

buildNpmPackage rec {
  pname = "ccmanager";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "kbwo";
    repo = "ccmanager";
    rev = "v1.2.0";
    hash = "sha256-Tmakd6kMUmBtTVnLkP8rj2tzLzGSNJ8ETCIIsfbhxcE=";
  };

  npmDepsHash = "sha256-OljqikTqLIn+hMjungjPDI3uy1ep6s5xyBCmp5rY8R0=";

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
