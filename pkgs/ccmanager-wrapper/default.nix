{ pkgs, ccmanager, ... }:

pkgs.writeShellScriptBin "ccmanager" ''
  export CCMANAGER_CLAUDE_ARGS="--dangerously-skip-permissions --resume"
  exec ${ccmanager}/bin/ccmanager "$@"
''