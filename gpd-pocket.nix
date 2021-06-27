{ pkgs, ... }:
{
  imports = [
    ./nixos-gpd-pocket/hardware.nix
    ./nixos-gpd-pocket/kernel.nix
    ./nixos-gpd-pocket/firmware.nix
    ./nixos-gpd-pocket/xserver.nix
    ./nixos-gpd-pocket/bluetooth.nix
    ./nixos-gpd-pocket/touch.nix
    ./nixos-gpd-pocket/power.nix
  ];

  #boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux_gpd_pocket;
  boot.kernelPatches = [ pkgs.linux_gpd_pocket_patches ];
  boot.initrd.kernelModules = pkgs.linux_gpd_pocket_modules;

  services.thermald.enable = true;
  services.tlp.enable = true;

  # hardware-configuration.nix sets a default value of powersave but that's a bad idea
  # when not using the intel_pstate driver. As we have enabled tlp, this will be set
  # via tlp instead of a dedicated cpufreq service.
  # ARK for Z8750 doesn't even mention Speed Shift Technology so I guess it is correct that intel_pstate isn't used here.
  # https://ark.intel.com/content/www/us/en/ark/products/93362/intel-atom-x7-z8750-processor-2m-cache-up-to-2-56-ghz.html
  #powerManagement.cpuFreqGovernor = "schedutil";
  powerManagement.cpuFreqGovernor = null;  # keep scheduler that is selected by the kernel

  # https://nixos.wiki/wiki/Accelerated_Video_Playback
  #nixpkgs.config.packageOverrides = pkgs: {
  #  vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  #};
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # LIBVA_DRIVER_NAME=iHD
      vaapiIntel         # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  environment.systemPackages = with pkgs; [ libva-utils ];
}
