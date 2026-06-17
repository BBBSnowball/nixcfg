{ lib, pkgs, ... }:

with lib;

#let
#  customSteam = pkgs.steam.override {
#    withPrimus = true;
#    extraPkgs = pkgs: with pkgs; [ glxinfo ];
#  };
#
#in
{
  hardware.opengl.enable = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio.support32Bit = true;

  programs.steam.enable = true;

  users.users.steam = {
    isNormalUser = true;
    uid = 1100;
    passwordFile = "/etc/secrets/passwords/steam";
    extraGroups = [
      "audio"
      "pulse-access"
      # FIXME a better workaround for gamepads not being accessible is required
      "input"
    ];
    packages = [
      #pkgs.steam
      pkgs.steam-run-native
      #pkgs.gamescope
    ];
  };
}
