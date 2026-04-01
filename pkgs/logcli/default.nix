{ grafana-loki, runCommand }:

runCommand "logcli-${grafana-loki.version}"
{
  meta = grafana-loki.meta // {
    description = "CLI for querying Grafana Loki";
    mainProgram = "logcli";
  };
}
  ''
    mkdir -p "$out/bin"
    ln -s ${grafana-loki}/bin/logcli "$out/bin/logcli"
  ''
