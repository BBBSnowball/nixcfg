{ lib, ... }:
let
in
{
  # enables usb-modeswitch, also useful for USB WiFi adapter that enumerates as CDROM, by default
  hardware.usbWwan.enable = true;

  # ModemManager needs polkit so keep it active although this is a headless system
  security.polkit.enable = lib.mkForce true;
}
