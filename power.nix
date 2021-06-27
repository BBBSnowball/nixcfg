{
  # make sure proper charging already works before unlocking the rootfs
   boot.initrd.kernelModules = [
    "bq24190_charger"
    "fusb302"
  ]; 

  # hardware-configuration.nix sets a default value of powersave but that's a bad idea
  # when not using the intel_pstate driver. As we have enabled tlp, this will be set
  # via tlp instead of a dedicated cpufreq service.
  # ARK for Z8750 doesn't even mention Speed Shift Technology so I guess it is correct that intel_pstate isn't used here.
  # https://ark.intel.com/content/www/us/en/ark/products/93362/intel-atom-x7-z8750-processor-2m-cache-up-to-2-56-ghz.html
  #powerManagement.cpuFreqGovernor = "schedutil";
  powerManagement.cpuFreqGovernor = null;  # keep scheduler that is selected by the kernel
}
