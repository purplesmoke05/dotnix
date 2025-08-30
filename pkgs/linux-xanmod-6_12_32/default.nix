# pkgs/linux-xanmod-6_12_32/default.nix (module version)
{ lib, config, pkgs, ... }:

let
  # Import the kernel package definition using local path
  customBuiltKernel = import ../linux-xanmod-6_12_32/kernel-package.nix {
    inherit lib pkgs;
    # Provide default kernelPatches; ensure it is a list
    kernelPatches = (config.boot.kernelPatches or [ ]) ++ (
      with pkgs.kernelPatches; [ bridge_stp_helper request_key_helper ]
    );
  };

  # Create a kernel package set using our custom built kernel
  # This ensures that it has the necessary structure, including the 'extend' method.
  customKernelPackages = pkgs.linuxPackagesFor customBuiltKernel;

in
{
  config = {
    # Set the boot.kernelPackages to our custom built kernel package, forcing its priority
    boot.kernelPackages = lib.mkForce customKernelPackages;
  };

  options.boot.customXanmodKernelPatches = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "Additional kernel patches to apply to the custom XanMod 6.12.32 kernel.";
  };
}
