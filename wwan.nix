{ config, pkgs, ... }:
{
  # enables usb-modeswitch, also useful for USB WiFi adapter that enumerates as CDROM, by default
  hardware.usbWwan.enable = true;

  nixpkgs.overlays = [ (import ./switch-E3531-to-tty.nix) ];
}
