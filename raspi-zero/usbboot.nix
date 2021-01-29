{ pkgs, ... }:
{
  nixpkgs.overlays = [ (import ./overlay.nix) ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0a5c", ATTR{idProduct}=="27[16][134]", GROUP="dialout"
  '';

  # enable /sys/class/gpio because we use that to control the nRESET/RUN line of the Pi
  boot.kernelPatches = [ {
    name = "gpio-in-sysfs";
    patch = null;
    extraConfig = ''GPIO_SYSFS y'';
  } ];
}
