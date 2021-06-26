{pkgs, ...}:
{
  hardware.bluetooth.enable = true;
  boot.kernelModules = [ "btusb" ];
  hardware.pulseaudio.package = pkgs.pulseaudioFull;

  services.udev.extraRules = ''
    # http://rolandtanglao.com/2017/09/05/p1-how-to-make-bluetooth-work-gpd-pocket-ubuntu/
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0000", ATTRS{idProduct}=="0000", RUN+="${pkgs.bash}/bin/bash -c 'modprobe btusb; echo 0000 0000 > /sys/bus/usb/drivers/btusb/new_id'"
  '';
}
