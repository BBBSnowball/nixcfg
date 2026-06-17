{ pkgs, lib, ... }:
with lib;

{
  services.udev.packages = singleton (pkgs.writeTextFile {
    name = "tv-serial-udev-rules";
    destination = "/etc/udev/rules.d/90-tv-serial.rules";
    text = ''
      SUBSYSTEM=="tty", ATTRS{idVendor}=="067b", ATTRS{idProduct}=="2303", SYMLINK+="tv-serial"
    '';
  });
}
