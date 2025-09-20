{ inputs, config, pkgs, username, ... }:

{
  # Hardware configuration / ハードウェア設定
  # Import laptop optimisations and xremap. / ラップトップ向け最適化モジュールを取り込む。
  imports = [
    ./hardware-configuration.nix
  ] ++ (with inputs.nixos-hardware.nixosModules; [
    common-cpu-amd
    common-pc-ssd
  ]) ++ [
    inputs.xremap.nixosModules.default
  ];

  # Power management / 電源管理
  # Control power and thermals with TLP and thermald. / TLP と thermald で熱制御。
  services.tlp.enable = true;
  services.thermald.enable = true;

  # User configuration / ユーザー設定
  # Grant admin and network groups to primary user. / 管理権限とネットワーク権限を付与。
  users.users.${username} = {
    isNormalUser = true;
    description = "Yosuke Otosu";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    ];
  };

  # Firewall configuration / ファイアウォール設定
  # Disabled; uncomment when needed. / 現在は無効。必要に応じて開放。
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # networking.firewall.enable = false;

  # NVIDIA driver / NVIDIA ドライバー
  # Enable proprietary GPU driver. / 専用 GPU ドライバーを有効化。
  services.xserver.videoDrivers = [ "nvidia" ];
}
