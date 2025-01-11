{ lib, ... }:
{
  services.printing.enable = true;
  services.system-config-printer.enable = true;
  #sound.enable = lib.mkOverride 500 true;
  #hardware.pulseaudio.enable = lib.mkOverride 500 true;

  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "altgr-intl";
      options = "eurosign:e";
    };
  };
  services.libinput.enable = true;
}
