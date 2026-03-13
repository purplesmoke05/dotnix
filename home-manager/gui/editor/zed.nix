{ pkgs, config, lib, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
  zedConfigDir =
    if isDarwin then
      "${config.home.homeDirectory}/Library/Application Support/Zed"
    else
      "${config.home.homeDirectory}/.config/zed";
  zedRepoDir = "${config.home.homeDirectory}/.nix/home-manager/gui/editor/zed";
  commonSettingsPath = "${zedRepoDir}/zed-settings.json";
  platformSettingsPath =
    if isDarwin then
      "${zedRepoDir}/zed-settings-darwin.json"
    else if isLinux then
      "${zedRepoDir}/zed-settings-linux.json"
    else
      "";
in
{
  home.packages = with pkgs; [
    zed-editor
  ];

  home.activation = lib.mkIf (isDarwin || isLinux) {
    writeZedConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "${zedConfigDir}"
      if [ -f "${commonSettingsPath}" ] || [ -n "${platformSettingsPath}" -a -f "${platformSettingsPath}" ]; then
        shared_tmp="$(mktemp)"
        platform_tmp="$(mktemp)"
        merged_tmp="$(mktemp)"
        cleanup() {
          rm -f "$shared_tmp" "$platform_tmp" "$merged_tmp"
        }
        trap cleanup EXIT

        if [ -f "${commonSettingsPath}" ]; then
          cp "${commonSettingsPath}" "$shared_tmp"
        else
          printf '{}\n' > "$shared_tmp"
        fi

        if [ -n "${platformSettingsPath}" ] && [ -f "${platformSettingsPath}" ]; then
          cp "${platformSettingsPath}" "$platform_tmp"
        else
          printf '{}\n' > "$platform_tmp"
        fi

        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$shared_tmp" "$platform_tmp" > "$merged_tmp"
        if [ "$(${pkgs.jq}/bin/jq 'length' "$merged_tmp")" -gt 0 ]; then
          $DRY_RUN_CMD cp --remove-destination "$merged_tmp" "${zedConfigDir}/settings.json"
          $DRY_RUN_CMD chmod 644 "${zedConfigDir}/settings.json"
        fi
        cleanup
        trap - EXIT
      fi
      $DRY_RUN_CMD cp --remove-destination ${./zed/zed-keymap.json} "${zedConfigDir}/keymap.json"
      $DRY_RUN_CMD chmod 644 "${zedConfigDir}/keymap.json"
    '';
  };
}







