{ lib
, python3
, symlinkJoin
, uv
, writeShellApplication
}:

let
  version = "0.34.0";
  excludeNewer = "2026-08-09T00:00:00Z";

  # headroom-ai installs litellm only below Python 3.14; litellm serves the litellm-* backends and extra pricing data, while these wrappers use the default backend and headroom's own pricing table. / headroom-ai は Python 3.14 以上では litellm を入れない。litellm は litellm-* のバックエンドと料金の補足に使うもので、このラッパーは既定のバックエンドと headroom 自身の料金表を使う。
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
        --python ${python3}/bin/python3 \
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
