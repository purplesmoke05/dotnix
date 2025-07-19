{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
}:

buildNpmPackage rec {
  pname = "ccmanager";
  version = "1.4.0";

  src = fetchFromGitHub {
    owner = "kbwo";
    repo = "ccmanager";
    rev = "v1.4.0";
    hash = "sha256-GSmjkGhtOpicPcllJxOGBc+mRD0bv9MeMgUpDMeyiF4=";
  };

  npmDepsHash = "sha256-lZ8FJwm92KKzTJwRMlVLiNolcN12l0dlTaceYFykwPY=";

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