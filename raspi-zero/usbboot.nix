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

  environment.systemPackages = with pkgs; [ rpiboot rpireset picocom ];

  systemd.services.rpireset-for-dialout = {
    serviceConfig.Type = "oneshot";
    wantedBy = [ "multi-user.target" ];
    script = ''
      # see rpireset in overlay.nix
      num=54
      [ -e /sys/class/gpio ] || ( echo "Kernel doesn't have CONFIG_GPIO_SYSFS!" >&2; exit 1 )
      [ -e /sys/class/gpio/gpio$num ] || echo $num >/sys/class/gpio/export
      echo 1 >/sys/class/gpio/gpio$num/value || true
      echo out >/sys/class/gpio/gpio$num/direction
      echo 1 >/sys/class/gpio/gpio$num/value
      chgrp dialout /sys/class/gpio/gpio$num/value
      chmod g+w /sys/class/gpio/gpio$num/value
    '';
  };
}
