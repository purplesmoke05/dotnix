# pkgs/linux-xanmod-6_16_7/kernel-package.nix
{ lib, pkgs, kernelPatches ? [ pkgs.kernelPatches.bridge_stp_helper pkgs.kernelPatches.request_key_helper ] }:

let
  base = pkgs.linux_xanmod_latest;
in
pkgs.buildLinux {
  inherit (base) version modDirVersion src;
  pname = "linux-xanmod-custom-${base.version}";

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

  extraMeta = base.meta or { } // {
    branch = lib.versions.majorMinor base.version;
    description = "Locally defined XanMod ${base.version} kernel";
    broken = pkgs.stdenv.hostPlatform.isAarch64;
  };

  argsOverride = { };
}
