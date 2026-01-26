{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "wtp";
  version = "2.6.0";

  src = fetchFromGitHub {
    owner = "satococoa";
    repo = "wtp";
    rev = "v${version}";
    hash = "sha256-bvBOu6hfSg4Rh5T5oxaqaTqi9AtNnbGwrbN+U0Zv3mQ=";
  };

  vendorHash = "sha256-wX6TeALJojynP4ocOR45WkayVVwvTr2LUbfAxuns9SM=";

  subPackages = [ "cmd/wtp" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  env = {
    CGO_ENABLED = 0;
  };

  doCheck = false;

  meta = with lib; {
    description = "Enhanced Git worktree management CLI";
    homepage = "https://github.com/satococoa/wtp";
    license = licenses.mit;
    mainProgram = "wtp";
    platforms = platforms.unix;
  };
}
