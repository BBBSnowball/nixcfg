{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    teensyduino
    teensy-loader-cli
    tytools
  ];

  services.udev.packages = [ pkgs.teensy-udev-rules ];

  nixpkgs.allowUnfreeByName = [
    "teensyduino"
    "teensy-udev-rules"
  ];
}
