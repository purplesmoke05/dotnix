# pkgs/linux-xanmod-6_12_21/default.nix (module version)
{ lib, config, pkgs, self, ... }:

let
  # Import the kernel package definition using self
  customBuiltKernel = import (self + "/pkgs/linux-xanmod-6_12_21/kernel-package.nix") {
    inherit lib pkgs;
    # Provide default kernelPatches, can be overridden by module options if needed
    kernelPatches = config.boot.kernelPatches ++ [
      # Add any specific default patches for this custom kernel here if necessary,
      # otherwise, rely on what's passed via config.boot.kernelPatches or module options.
      # For now, using the common ones as a base, similar to how overlays might do.
      pkgs.kernelPatches.bridge_stp_helper
      pkgs.kernelPatches.request_key_helper
    ];
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

  # Optionally, define an option to customize patches for this specific kernel module
  options.boot.customXanmodKernelPatches = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [];
    description = "Additional kernel patches to apply to the custom XanMod 6.12.21 kernel.";
  };

  # If customXanmodKernelPatches is set, we might need to re-evaluate customKernelPkg with these.
  # This part is a bit more advanced and might require customKernelPkg to accept patches directly
  # or modifying its `kernelPatches` argument based on `config.boot.customXanmodKernelPatches`.
  # For simplicity, the current `kernel-package.nix` takes `kernelPatches` as an argument,
  # and we are providing some defaults. If more dynamic patching is needed, this structure
  # would need to be more sophisticated, perhaps by making `customKernelPkg` a function of `config`.
}