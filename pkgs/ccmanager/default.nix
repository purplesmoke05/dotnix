{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
}:

buildNpmPackage rec {
  pname = "ccmanager";
  version = "0.1.14";

  src = fetchFromGitHub {
    owner = "kbwo";
    repo = "ccmanager";
    rev = "v0.1.14";
    hash = "sha256-x56HvjetpaaLj62gUiIRtJDsMUvrsW9PdWU3woJcytQ=";
  };

  npmDepsHash = "sha256-RkjmOWrhAw2BZC4MVACudqP9NA2gEFQgocnTdSpO1ZU=";

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