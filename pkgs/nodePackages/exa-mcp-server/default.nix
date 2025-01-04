{ lib, buildNpmPackage, fetchFromGitHub, nodejs }:

buildNpmPackage rec {
  pname = "exa-mcp-server";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "exa-labs";
    repo = "exa-mcp-server";
    rev = "8566688";
    sha256 = "sha256-5Atb7HuhkxfA2Sei5ScESzkw27XU/mc+g8vjQsQc9X4=";
  };

  buildInputs = [ nodejs ];

  npmFlags = [ "--legacy-peer-deps" ];

  npmDepsHash = "sha256-w8OYNs/ETFcyni5C+uR8F7H4KHQ7uUHobicaIlJVawo=";

  meta = with lib; {
    description = "Claude can perform Web Search | Exa with MCP (Model Context Protocol)";
    homepage = "https://github.com/exa-labs/exa-mcp-server";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
}