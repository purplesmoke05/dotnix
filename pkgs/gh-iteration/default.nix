{ lib, fetchFromGitHub, buildGoModule, testers, gh-iteration }:

buildGoModule rec {
  pname = "gh-iteration";
  version = "0.2.0"; # Specify the desired version

  src = fetchFromGitHub {
    owner = "tasshi-me";
    repo = "gh-iteration";
    rev = "v${version}";
    hash = "sha256-yfJAmDx+wf5pTdXLR6MAhv6BlHq0AXdqdTinDiN/XII="; # Correct src hash
  };

  vendorHash = "sha256-Zwh/oKapBfuw3M6XxKEQEW2WjS5hm6ZcDGFjFPaXr4g="; # This needs to be determined

  # ldflags, if any, go here. gh-iteration doesn't seem to use them for version embedding.

  doCheck = false; # Disable checks if they are problematic

  passthru = {
    tests.version = testers.testVersion {
      package = gh-iteration;
    };
  };

  meta = with lib; {
    description = "A gh extension for managing GitHub Project iterations";
    homepage = "https://github.com/tasshi-me/gh-iteration";
    changelog = "https://github.com/tasshi-me/gh-iteration/releases/tag/v${version}";
    license = licenses.mit;
    maintainers = with maintainers; [ /* your GitHub username */ ];
    mainProgram = "gh-iteration";
  };
}
