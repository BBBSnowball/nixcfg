{ pkgs, ... }:
{
  #nixpkgs.config.allowUnfree = true; # for firmware
  #hardware.enableAllFirmware = true;  #FIXME can we enable more specific packages?
  hardware.firmware = with pkgs; [ firmwareLinuxNonfree ];
}
