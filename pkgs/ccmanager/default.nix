{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
}:

buildNpmPackage rec {
  pname = "ccmanager";
  version = "2.9.2";

  src = fetchFromGitHub {
    owner = "kbwo";
    repo = "ccmanager";
    rev = "v2.9.2";
    hash = "sha256-kiMLaj4NBUC+RnOh0RY8pGQ0013vdCcboaXSlJh5ZTA=";
  };

  npmDepsHash = "sha256-YsBfRLkGXv7r5vsXxfmUiim7Wy9FOCTYhguHrXzIfpU=";

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
