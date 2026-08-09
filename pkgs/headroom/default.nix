{ lib
, python313
, symlinkJoin
, uv
, writeShellApplication
}:

let
  version = "0.34.0";
  excludeNewer = "2026-08-09T00:00:00Z";

  headroomCli = writeShellApplication {
    name = "headroom";
    runtimeInputs = [ uv ];
    text = ''
      exec uvx \
        --isolated \
        --no-config \
        --no-managed-python \
        --no-progress \
        --no-build \
        --exclude-newer ${excludeNewer} \
        --python ${python313}/bin/python3 \
        --from "headroom-ai[proxy]==${version}" \
        headroom "$@"
    '';
  };

  codexHeadroom = writeShellApplication {
    name = "codex-headroom";
    runtimeInputs = [ headroomCli ];
    text = ''
      export HEADROOM_DISABLE_KOMPRESS="''${HEADROOM_DISABLE_KOMPRESS:-1}"
      export HEADROOM_TELEMETRY="''${HEADROOM_TELEMETRY:-off}"

      exec headroom wrap codex --code-memory none -- "$@"
    '';
  };
in
symlinkJoin {
  name = "headroom-${version}";
  paths = [
    headroomCli
    codexHeadroom
  ];

  passthru = {
    inherit version;
  };

  meta = {
    description = "Pinned Headroom launcher with an opt-in Codex wrapper";
    homepage = "https://github.com/headroomlabs-ai/headroom";
    license = lib.licenses.asl20;
    mainProgram = "headroom";
    platforms = lib.platforms.unix;
  };
}
