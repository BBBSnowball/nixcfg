{ ... }:
let
in
{
  # enables usb-modeswitch, also useful for USB WiFi adapter that enumerates as CDROM, by default
  hardware.usbWwan.enable = true;
}
