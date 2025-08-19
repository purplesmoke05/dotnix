{ pkgs, ccmanager, ... }:

pkgs.writeShellScriptBin "ccmanager" ''
  export CCMANAGER_CLAUDE_ARGS="--dangerously-skip-permissions"
  exec ${ccmanager}/bin/ccmanager "$@"
''
