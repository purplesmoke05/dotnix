# pkgs/linux-xanmod-6_12_32/kernel-package.nix
{ lib, pkgs, kernelPatches ? [ pkgs.kernelPatches.bridge_stp_helper pkgs.kernelPatches.request_key_helper ] }:

let
  # Definition for 6.12.32 LTS from xanmod/linux tags
  xanmod_lts_6_12_32 = {
    version = "6.12.32";
    hash = "sha256-b5hoYHsufqCCgZ11u1MZUVdNQrnkGC8L0h6xRzmZbt8=";
    suffix = "xanmod1"; # Default suffix
  };
in
pkgs.buildLinux {
  inherit (xanmod_lts_6_12_32) version suffix; # hash is used in src directly
  pname = "linux-xanmod-lts-6.12.32"; # Custom pname
  modDirVersion = lib.versions.pad 3 "${xanmod_lts_6_12_32.version}-${xanmod_lts_6_12_32.suffix}";

  src = pkgs.fetchFromGitLab {
    owner = "xanmod";
    repo = "linux";
    rev = lib.versions.pad 3 "${xanmod_lts_6_12_32.version}-${xanmod_lts_6_12_32.suffix}";
    hash = xanmod_lts_6_12_32.hash;
  };

  structuredExtraConfig = with lib.kernel; {
    # Disable Rust support to avoid rustc compatibility build failures on unstable
    RUST = lib.mkOverride 60 no;
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
    branch = lib.versions.majorMinor xanmod_lts_6_12_32.version;
    description = "Locally defined XanMod LTS ${xanmod_lts_6_12_32.version} kernel";
    broken = pkgs.stdenv.hostPlatform.isAarch64; # stdenv is now accessed via pkgs
  };

  argsOverride = { };
}
