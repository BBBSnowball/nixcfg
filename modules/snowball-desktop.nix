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

  #sound.enable = lib.mkOverride 500 true;
  #hardware.pulseaudio.enable = lib.mkOverride 500 true;

  environment.systemPackages = with pkgs; [
    meld
    firefox pavucontrol chromium
    mplayer mpv vlc
    speedcrunch
    libreoffice gimp
    inkscape
    w3m
    gitui gitg
    iw wirelesstools
    qrencode  # also useful for cli with `-t ANSI` but I will prefer SSH/SFTP for headless systems
    (self.packages.${pkgs.stdenv.hostPlatform.system}.add_recently_used or self.inputs.routeromen.packages.${pkgs.stdenv.hostPlatform.system}.add_recently_used)
    clementine
    xorg.xev
    #glxinfo
    mesa-demos
  ] ++ (builtins.filter (p: p.meta.available) [
    # These are not available for aarch64-linux at the moment.
    mplayer
  ]) ++ (with pkgs.gnome; with pkgs; [
    # Avoid warning in 24.11 by not accessing them through pkgs.gnome when possible.
    eog
    evince
    cheese
    gnome-screenshot
  ]);

  # already defined by snowball-big, so use a different priority to avoid a conflict
  programs.git.package = lib.mkOverride 200 pkgs.gitFull;  # provides `git gui`
}
