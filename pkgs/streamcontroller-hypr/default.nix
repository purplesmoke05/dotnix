{ writeShellScriptBin, coreutils, streamcontroller }:

writeShellScriptBin "streamcontroller-hypr" ''
  set -euo pipefail

  runtime_dir="$XDG_RUNTIME_DIR"
  if [ -z "$runtime_dir" ]; then
    runtime_dir="/run/user/$(${coreutils}/bin/id -u)"
  fi
  hypr_dir="$runtime_dir/hypr"

  sig=""
  if [ -d "$hypr_dir" ]; then
    sig="$(${coreutils}/bin/ls -1t "$hypr_dir" 2>/dev/null | ${coreutils}/bin/head -n1 || true)"
  fi

  if [ -n "$sig" ]; then
    export HYPRLAND_INSTANCE_SIGNATURE="$sig"
  fi

  exec ${streamcontroller}/bin/streamcontroller "$@"
''
