{ pkgs, ... }:

{
  hardware.cpu.intel.updateMicrocode = true;

  environment.systemPackages = with pkgs; [
    i7z
  ];
}