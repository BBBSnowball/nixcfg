{ lib, ... }:
{
  services.printing.enable = true;
  services.system-config-printer.enable = true;
  sound.enable = true;
  hardware.pulseaudio.enable = lib.mkOverride 500 true;

  services.xserver.enable = true;
  services.xserver.layout = "us";
  services.xserver.xkbOptions = "eurosign:e";
  services.xserver.libinput.enable = true;
}
