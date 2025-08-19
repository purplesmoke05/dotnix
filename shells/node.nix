{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  name = "node-dev";

  buildInputs = with pkgs; [
    nodejs
    nodePackages.npm
    nodePackages.yarn
    nodePackages.pnpm
  ];

  shellHook = ''
    echo "Node.js development environment"
    echo "You can install ccmanager with: npm install -g ccmanager"
    echo "Or add it to your project: npm install ccmanager"
  '';
}
