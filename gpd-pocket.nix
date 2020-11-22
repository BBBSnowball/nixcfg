{ pkgs, ... }:
{
  imports = [
    ./nixos-gpd-pocket/hardware.nix
    ./nixos-gpd-pocket/kernel.nix
    ./nixos-gpd-pocket/firmware
    ./nixos-gpd-pocket/xserver.nix
    ./nixos-gpd-pocket/bluetooth.nix
    ./nixos-gpd-pocket/touch.nix
  ];

  nixpkgs.config.allowUnfree = true; # for firmware

  # neet 4.14+ for proper hardware support (and modesetting)
  # especially for screen rotation on boot
  boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux_gpd_pocket;
  boot.initrd.kernelModules = [
    "pwm-lpss" "pwm-lpss-platform" # for brightness control
    "g_serial" # be a serial device via OTG
  ];

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
}
