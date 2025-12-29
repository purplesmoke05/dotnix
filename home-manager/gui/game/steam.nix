{ pkgs, lib, ... }:

let
  pythonWithVdf = pkgs.python312.withPackages (ps: [ ps.vdf ]);
in
{
  # Ensure Proton GE compatibility tool symlinks exist. / Proton GE 互換ツールへのシンボリックリンクを確保。
  home.file.".steam/root/compatibilitytools.d/GE-Proton".source =
    pkgs.proton-ge-bin.steamcompattool;
  home.file.".local/share/Steam/compatibilitytools.d/GE-Proton".source =
    pkgs.proton-ge-bin.steamcompattool;

  # Ensure Steam UI uses CJK-capable fonts. / Steam UI が CJK 対応フォントを必ず使うようにする。
  xdg.configFile."fontconfig/conf.d/99-steam.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <description>Force JP fonts for Steam UI</description>
      <!-- Apply to Steam binaries / Steam バイナリに適用 -->
      <match target="pattern">
        <test name="prgname" compare="contains">
          <string>steam</string>
        </test>
        <edit mode="prepend" name="family" binding="strong">
          <string>Noto Sans CJK JP</string>
          <string>IPAGothic</string>
        </edit>
      </match>
      <match target="pattern">
        <test name="prgname" compare="contains">
          <string>steamwebhelper</string>
        </test>
        <edit mode="prepend" name="family" binding="strong">
          <string>Noto Sans CJK JP</string>
          <string>IPAGothic</string>
        </edit>
      </match>
      <!-- Alias Steam UI fonts / Steam UI フォントに別名を張る -->
      <alias binding="same">
        <family>Motiva Sans</family>
        <prefer>
          <family>Noto Sans CJK JP</family>
          <family>IPAGothic</family>
        </prefer>
      </alias>
      <alias binding="same">
        <family>Steam Sans</family>
        <prefer>
          <family>Noto Sans CJK JP</family>
          <family>IPAGothic</family>
        </prefer>
      </alias>
      <alias binding="same">
        <family>Segoe UI</family>
        <prefer>
          <family>Noto Sans CJK JP</family>
          <family>IPAGothic</family>
        </prefer>
      </alias>
      <alias binding="same">
        <family>Arial</family>
        <prefer>
          <family>Noto Sans CJK JP</family>
          <family>IPAGothic</family>
        </prefer>
      </alias>
      <alias binding="same">
        <family>Helvetica</family>
        <prefer>
          <family>Noto Sans CJK JP</family>
          <family>IPAGothic</family>
        </prefer>
      </alias>
      <alias binding="same">
        <family>Verdana</family>
        <prefer>
          <family>Noto Sans CJK JP</family>
          <family>IPAGothic</family>
        </prefer>
      </alias>
      <alias binding="same">
        <family>sans-serif</family>
        <prefer>
          <family>Noto Sans CJK JP</family>
          <family>IPAGothic</family>
        </prefer>
      </alias>
      <alias binding="same">
        <family>sans</family>
        <prefer>
          <family>Noto Sans CJK JP</family>
          <family>IPAGothic</family>
        </prefer>
      </alias>
      <alias binding="same">
        <family>GoNotoKurrent</family>
        <prefer>
          <family>Noto Sans CJK JP</family>
          <family>IPAGothic</family>
        </prefer>
      </alias>
      <alias binding="same">
        <family>GoNotoKurrent UI</family>
        <prefer>
          <family>Noto Sans CJK JP</family>
          <family>IPAGothic</family>
        </prefer>
      </alias>
      <alias binding="same">
        <family>GoNotoCurrent</family>
        <prefer>
          <family>Noto Sans CJK JP</family>
          <family>IPAGothic</family>
        </prefer>
      </alias>
    </fontconfig>
  '';

  # Deploy fonts and CSS as real files inside Steam tree to bypass symlink restrictions. / Steam ツリー内に実体配置してサンドボックス・検証の制約を回避。
  # Force Steam UI CSS to prefer JP-capable fonts. / Steam UI の CSS で日本語対応フォントを優先させる。
  home.file.".local/share/Steam/steamui/libraryroot.custom.css" = {
    text = ''
      :root, body {
        font-family: "Noto Sans CJK JP","IPAGothic","Motiva Sans","Steam Sans",system-ui,sans-serif !important;
      }
      :lang(ja), :lang(ja-JP) {
        font-family: "Noto Sans CJK JP","IPAGothic","Motiva Sans","Steam Sans",system-ui,sans-serif !important;
      }
    '';
    force = true;
  };

  # Ship CJK fonts directly into Steam UI font search paths. / Steam UI のフォント検索パスに CJK フォントを直接配置する。
  home.file.".local/share/Steam/steamui/fonts/NotoSansCJK-VF.otf.ttc" = {
    source = "${pkgs.noto-fonts-cjk-sans}/share/fonts/opentype/noto-cjk/NotoSansCJK-VF.otf.ttc";
    force = true;
  };
  home.file.".local/share/Steam/clientui/fonts/NotoSansCJK-VF.otf.ttc" = {
    source = "${pkgs.noto-fonts-cjk-sans}/share/fonts/opentype/noto-cjk/NotoSansCJK-VF.otf.ttc";
    force = true;
  };
  home.file.".local/share/Steam/clientui/fonts/ipag.ttf" = {
    source = "${pkgs.ipafont}/share/fonts/opentype/ipag.ttf";
    force = true;
  };
  home.file.".local/share/fonts/NotoSansCJK-VF.otf.ttc" = {
    source = "${pkgs.noto-fonts-cjk-sans}/share/fonts/opentype/noto-cjk/NotoSansCJK-VF.otf.ttc";
    force = true;
  };
  home.file.".local/share/fonts/ipag.ttf" = {
    source = "${pkgs.ipafont}/share/fonts/opentype/ipag.ttf";
    force = true;
  };

  # Ensure Steam games inhibit idle; keep SF6 on MangoHud + GameMode. / Steam ゲームのアイドル抑止を追加し、SF6は MangoHud + GameMode を維持。
  home.activation.ensureSteamLaunchOptions =
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
      sf6_app_id = "1364780"
      base_prefix = 'systemd-inhibit --what=idle --mode=block --why="gaming"'

      def normalize(value):
          if value is None:
              return None
          if not isinstance(value, str):
              return str(value)
          return value.strip()

      def ensure_prefix(value):
          value = normalize(value)
          if not value:
              return f"{base_prefix} %command%"
          if base_prefix in value:
              return value
          return f"{base_prefix} {value}"
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
      for app_id, app_block in apps_store.items():
          if not isinstance(app_block, dict):
              continue
          current = app_block.get("LaunchOptions")
          updated = ensure_prefix(current)
          if current != updated:
              app_block["LaunchOptions"] = updated

      sf6_block = apps_store.setdefault(sf6_app_id, {})
      desired_sf6 = f"{base_prefix} mangohud gamemoderun %command%"
      if sf6_block.get("LaunchOptions") != desired_sf6:
          sf6_block["LaunchOptions"] = desired_sf6
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
