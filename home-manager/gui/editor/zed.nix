{ pkgs, config, lib, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
  zedConfigDir =
    if isDarwin then
      "${config.home.homeDirectory}/Library/Application Support/Zed"
    else
      "${config.home.homeDirectory}/.config/zed";
in
{
  home.packages = with pkgs; [
    zed-editor
  ];

  home.activation = lib.mkIf (isDarwin || isLinux) {
    writeZedKeymap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "${zedConfigDir}"
      $DRY_RUN_CMD cp --remove-destination ${./zed/zed-keymap.json} "${zedConfigDir}/keymap.json"
      $DRY_RUN_CMD chmod 644 "${zedConfigDir}/keymap.json"
    '';
  };
}











