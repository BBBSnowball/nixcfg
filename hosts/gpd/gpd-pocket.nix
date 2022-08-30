{ pkgs, nixpkgs-old, ... }:
{
  imports = [
    ./nixos-gpd-pocket/hardware.nix
    ./nixos-gpd-pocket/kernel.nix
    ./nixos-gpd-pocket/firmware.nix
    ./nixos-gpd-pocket/xserver.nix
    ./nixos-gpd-pocket/bluetooth.nix
    ./nixos-gpd-pocket/suspend.nix
    ./nixos-gpd-pocket/power.nix
    #./nixos-gpd-pocket/scrolling.nix
  ];

  #boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux_gpd_pocket;
  boot.kernelPatches = [ pkgs.linux_gpd_pocket_patches ];
  boot.initrd.kernelModules = pkgs.linux_gpd_pocket_modules;

  services.thermald.enable = true;
  services.tlp.enable = true;

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

  # downgrade kernel because of audio problems (very loud noise)
  boot.kernelPackages = nixpkgs-old.legacyPackages.${pkgs.system}.linuxPackages;
}
