{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
}:

buildNpmPackage rec {
  pname = "ccmanager";
  version = "1.4.2";

  src = fetchFromGitHub {
    owner = "kbwo";
    repo = "ccmanager";
    rev = "v1.4.2";
    hash = "sha256-mW71TFWr8bVpPS45XOshbe5ccJUsndMYPR1mGR6JBvg=";
  };

  npmDepsHash = "sha256-FzKSEFdHPgemf7aP2WkhSvpQGauH4nUWRMXPmt5e6zQ=";

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