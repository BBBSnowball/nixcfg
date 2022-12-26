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

  environment.systemPackages = with pkgs; [
    meld
    firefox pavucontrol chromium
    mplayer mpv vlc
    speedcrunch
    gnome.eog gnome.evince
    w3m
    (git.override { guiSupport = true; })
    gnome.gnome-screenshot
    iw wirelesstools
  ];
}
