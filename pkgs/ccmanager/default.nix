{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
}:

buildNpmPackage rec {
  pname = "ccmanager";
  version = "2.2.2";

  src = fetchFromGitHub {
    owner = "kbwo";
    repo = "ccmanager";
    rev = "v2.2.2";
    hash = "sha256-8lfXfuFuXCLrXzuFQPw0UdlJFVrnKz2G5HJljzs5jqY=";
  };

  npmDepsHash = "sha256-N0A4ZeUqO5nQXot1WVXFUBNR1Lg3lala7fNS0nJ9dJc=";

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