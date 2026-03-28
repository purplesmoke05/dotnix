{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
}:

buildNpmPackage rec {
  pname = "ccmanager";
  version = "3.0.0";

  src = fetchFromGitHub {
    owner = "kbwo";
    repo = "ccmanager";
    rev = "v3.0.0";
    hash = "sha256-dhnp58cLQSKURnWoek7vbfBAPpdeqxW58UOflI3SNRk=";
  };

  npmDepsHash = "sha256-sxzM0Oao5jPydOsusZKBZPL9pGoRNYh1beAi+2OhyGM=";

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
