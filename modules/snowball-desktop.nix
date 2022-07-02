{ lib, config, modules, ... }:
{
  imports = [ modules.snowball-big ];

  services.printing.enable = true;

  sound.enable = lib.mkOverride 500 true;
  hardware.pulseaudio.enable = lib.mkOverride 500 true;
}
