{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
}:

buildNpmPackage rec {
  pname = "ccmanager";
  version = "0.1.9";

  src = fetchFromGitHub {
    owner = "kbwo";
    repo = "ccmanager";
    rev = "v0.1.9";
    hash = "sha256-U8BOlZLkvJjlkm7IfkkhhfnXSytKEgmRoCCrPPZJvAc=";
  };

  npmDepsHash = "sha256-YhX6H5E4N4lgukYiuOx8jTxsizS0OMjXJnGXjYKmKVU=";

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