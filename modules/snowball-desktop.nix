{ lib, config, pkgs, modules, self, ... }:
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
    mpv vlc
    speedcrunch
    gnome.eog gnome.evince
    w3m
    gitFull  # provides `git gui`
    gitui gitg
    gnome.gnome-screenshot
    iw wirelesstools
    qrencode  # also useful for cli with `-t ANSI` but I will prefer SSH/SFTP for headless systems
    (self.packages.${pkgs.stdenv.hostPlatform.system}.add_recently_used or self.inputs.routeromen.packages.${pkgs.stdenv.hostPlatform.system}.add_recently_used)
  ] ++ (builtins.filter (p: p.meta.available) [
    # These are not available for aarch64-linux at the moment.
    mplayer
  ]);
}
