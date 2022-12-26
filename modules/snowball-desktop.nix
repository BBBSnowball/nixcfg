{ lib, config, pkgs, modules, ... }:
{
  imports = with modules; [
    snowball-big
    allowUnfree
  ];

  services.printing.enable = true;
  #services.printing.drivers = with pkgs; [
  #  brlaser
  #  #mfc9140cdnlpr
  #  mfc9140cdncupswrapper
  #];

  #nixpkgs.allowUnfreeByName = [ "mfc9140cdnlpr" ];

  sound.enable = lib.mkOverride 500 true;
  hardware.pulseaudio.enable = lib.mkOverride 500 true;
}
