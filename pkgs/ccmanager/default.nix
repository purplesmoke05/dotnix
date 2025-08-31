{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
}:

buildNpmPackage rec {
  pname = "ccmanager";
  version = "2.4.0";

  src = fetchFromGitHub {
    owner = "kbwo";
    repo = "ccmanager";
    rev = "v2.4.0";
    hash = "sha256-lc0ObGpS3HfystNxpmC+BwNB+w4+8aWREHVoJRQVYQo=";
  };

  npmDepsHash = "sha256-iEkwFsffZxlqpHCOSukK56HuDN0dB3ZP4TVN1ectRac=";

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
