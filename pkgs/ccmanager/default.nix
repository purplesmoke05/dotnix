{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
}:

buildNpmPackage rec {
  pname = "ccmanager";
  version = "2.2.4";

  src = fetchFromGitHub {
    owner = "kbwo";
    repo = "ccmanager";
    rev = "v2.2.4";
    hash = "sha256-sZwEgSxia8NuHJ+IgVlqJI4nU6DmQPdmfN3h1tqYLgQ=";
  };

  npmDepsHash = "sha256-SSxlIkupdhsCviDmUjX+3BwpRJutQmAsnV2APN65xuY=";

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
