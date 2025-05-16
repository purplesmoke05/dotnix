# pkgs/linux-xanmod-6_12_21/kernel-package.nix
{ lib, pkgs, kernelPatches ? [ pkgs.kernelPatches.bridge_stp_helper pkgs.kernelPatches.request_key_helper ] }:

let
  # Definition for 6.12.21 LTS from nixpkgs@d19cf9df...
  xanmod_lts_6_12_21 = {
    version = "6.12.21";
    hash = "sha256-Zb/n+hLho94+6u5BHAmRYfit/kv1xlh/Tp39kI3kfjA="; # From the old xanmod-kernels.nix
    suffix = "xanmod1"; # Default suffix
  };
in
pkgs.buildLinux { # buildLinux is now accessed via pkgs
  inherit (xanmod_lts_6_12_21) version suffix; # hash is used in src directly
  pname = "linux-xanmod-lts-6.12.21"; # Custom pname
  modDirVersion = lib.versions.pad 3 "${xanmod_lts_6_12_21.version}-${xanmod_lts_6_12_21.suffix}";

  src = pkgs.fetchFromGitLab { # fetchFromGitLab is now accessed via pkgs
    owner = "xanmod";
    repo = "linux";
    rev = lib.versions.pad 3 "${xanmod_lts_6_12_21.version}-${xanmod_lts_6_12_21.suffix}";
    hash = xanmod_lts_6_12_21.hash;
  };

  structuredExtraConfig = with lib.kernel; {
    CPU_FREQ_DEFAULT_GOV_PERFORMANCE = lib.mkOverride 60 yes;
    CPU_FREQ_DEFAULT_GOV_SCHEDUTIL = lib.mkOverride 60 no;
    PREEMPT = lib.mkOverride 60 yes;
    PREEMPT_VOLUNTARY = lib.mkOverride 60 no;
    TCP_CONG_BBR = yes;
    DEFAULT_BBR = yes;
    HZ = freeform "250";
    HZ_250 = yes;
    HZ_1000 = no;
    RCU_EXPERT = yes;
    RCU_FANOUT = freeform "64";
    RCU_FANOUT_LEAF = freeform "16";
    RCU_BOOST = yes;
    RCU_BOOST_DELAY = freeform "0";
    RCU_EXP_KTHREAD = yes;
  };

  inherit kernelPatches;

  extraMeta = {
    branch = lib.versions.majorMinor xanmod_lts_6_12_21.version;
    description = "Locally defined XanMod LTS ${xanmod_lts_6_12_21.version} kernel";
    broken = pkgs.stdenv.hostPlatform.isAarch64; # stdenv is now accessed via pkgs
  };

  argsOverride = {};
}