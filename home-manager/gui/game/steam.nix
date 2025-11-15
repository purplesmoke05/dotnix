{ pkgs, lib, ... }:

let
  pythonWithVdf = pkgs.python3.withPackages (ps: [ ps.vdf ]);
in
{
  # Ensure Proton GE compatibility tool symlinks exist. / Proton GE 互換ツールへのシンボリックリンクを確保。
  home.file.".steam/root/compatibilitytools.d/GE-Proton".source =
    pkgs.proton-ge-bin.steamcompattool;
  home.file.".local/share/Steam/compatibilitytools.d/GE-Proton".source =
    pkgs.proton-ge-bin.steamcompattool;

  # Force gamemoderun launch option for Street Fighter 6. / Street Fighter 6 を常に gamemoderun で起動。
  home.activation.ensureSF6Gamemode =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -euo pipefail
      shopt -s nullglob
      sf6_app_id=1364780
      python_bin=${pythonWithVdf}/bin/python3
      update_launch_opts() {
        local config_file="$1"
        if [ ! -f "$config_file" ]; then
          return 0
        fi
        $DRY_RUN_CMD "$python_bin" - "$config_file" <<'PY'
import sys
import vdf

config_path = sys.argv[1]
app_id = "1364780"
try:
    with open(config_path, "r", encoding="utf-8", errors="ignore") as fh:
        data = vdf.load(fh)
except FileNotFoundError:
    sys.exit(0)

steam_root = (
    data.setdefault("UserLocalConfigStore", {})
    .setdefault("Software", {})
    .setdefault("Valve", {})
    .setdefault("Steam", {})
)
apps_store = steam_root.setdefault("apps", steam_root.get("Apps", {}))
# Keep legacy key in sync if it exists / existed. / 互換用キーがあれば同期。
steam_root["Apps"] = apps_store
app_block = apps_store.setdefault(app_id, {})

desired = "gamemoderun %command%"
if app_block.get("LaunchOptions") == desired:
    sys.exit(0)

app_block["LaunchOptions"] = desired
with open(config_path, "w", encoding="utf-8") as fh:
    vdf.dump(data, fh)
PY
      }

      for userdata_root in "$HOME/.steam/root/userdata" "$HOME/.local/share/Steam/userdata"; do
        [ -d "$userdata_root" ] || continue
        for user_dir in "$userdata_root"/*; do
          [ -d "$user_dir" ] || continue
          config_file="$user_dir/config/localconfig.vdf"
          update_launch_opts "$config_file"
        done
      done
    '';
}
