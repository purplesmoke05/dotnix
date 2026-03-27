{ lib
, rustPlatform
, fetchCrate
}:

rustPlatform.buildRustPackage rec {
  pname = "excel-cli";
  version = "0.4.2";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-FE/8HS4rkoqg4ObI1el1vxV/2K8U01W96mTD7EM1H+A=";
  };

  cargoHash = "sha256-E7M9kQQllNJcebe8pAj9QTIuM7bMOZT0DSwvOmTvkcc=";

  meta = with lib; {
    description = "A lightweight terminal-based Excel viewer with Vim-like navigation";
    homepage = "https://github.com/fuhan666/excel-cli";
    license = licenses.mit;
    mainProgram = "excel-cli";
    platforms = platforms.unix;
  };
}
