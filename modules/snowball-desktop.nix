{ lib, config, pkgs, modules, ... }:
{
  imports = [ modules.snowball-big ];

  services.printing.enable = true;
  #services.printing.drivers = with pkgs; [
  #  brlaser
  #  #mfc9140cdnlpr
  #  mfc9140cdncupswrapper
  #];

  ##NOTE This doesn't seem to get merged with other definitions of the same setting!
  #nixpkgs.config.allowUnfreePredicate = pkg: lib.trace "abc" (builtins.elem (lib.getName pkg) [
  #  "mfc9140cdnlpr"
  #]);

  sound.enable = lib.mkOverride 500 true;
  hardware.pulseaudio.enable = lib.mkOverride 500 true;
}
