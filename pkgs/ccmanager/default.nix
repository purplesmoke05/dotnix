{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
}:

buildNpmPackage rec {
  pname = "ccmanager";
  version = "2.6.1";

  src = fetchFromGitHub {
    owner = "kbwo";
    repo = "ccmanager";
    rev = "v2.6.1";
    hash = "sha256-uDFvUzkGqVA6vHsANwONHUaE8K9K7Vy3yscxjxaywcU=";
  };

  npmDepsHash = "sha256-zK460FAwyPuu991dznhz5mjxS4FS0ArrVmRNgzlK4gA=";

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
