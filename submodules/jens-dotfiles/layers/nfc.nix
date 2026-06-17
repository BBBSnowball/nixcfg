{ config, pkgs, lib, ... }:
with lib;

{
  services.udev.packages = singleton (pkgs.writeTextFile {
    name = "nfc-uart-udev-rules";
    destination = "/etc/udev/rules.d/90-nfc-uart.rules";
    text = ''
      SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", GROUP="dialout", SYMLINK+="nfc-uart"
    '';
  });

  environment.etc."nfc/libnfc.conf".text = ''
    device.name = "PN532 board via UART"
    device.connstring = pn532_uart:/dev/nfc-uart
  '';
}
