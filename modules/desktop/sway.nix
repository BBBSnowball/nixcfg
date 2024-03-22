{ pkgs, ... }:
{
  #services.xserver.displayManager.lightdm.enable = true;
  #services.xserver.desktopManager.xfce.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  #services.xserver.desktopManager.gnome.enable = true;

  programs.sway.enable = true;
  programs.sway.wrapperFeatures.gtk = true;
  programs.sway.extraPackages = with pkgs; [
    alacritty kitty foot dmenu kupfer
    i3status i3status-rust termite rofi light
    swaylock
    wdisplays
    brightnessctl  # uses logind so doesn't need root
    sway-contrib.grimshot
    #yubikey-agent
    #yubikey-touch-detector
    mako
    pulseaudio
    playerctl
    libnotify
    (pkgs.runCommand "notify-helpers" { inherit (pkgs) jq; } ''
      mkdir $out/bin -p
      cp ${./notify-brightness.sh} $out/bin/notify-brightness
      substituteAll ${./notify-volume.sh} $out/bin/notify-volume
      chmod +x $out/bin/*
      patchShebangs $out/bin/*
    '')
    system-config-printer
    kupfer
    gnome.gnome-screenshot
    gnome.gnome-tweaks
    gnome.nautilus
  ];
  environment.etc."sway/config".source = ./sway-config;
  environment.etc."alacritty.yml".source = ./alacritty.yml;
  #environment.etc."i3status.conf".source = ./i3status.conf;
  environment.etc."xdg/i3status/config".source = ./i3status.conf;
  hardware.opengl.enable = true;
  # create /etc/X11/xkb for `localectl list-x11-keymap-options`
  # https://github.com/NixOS/nixpkgs/issues/19629#issuecomment-368051434
  services.xserver.exportConfiguration = true;
}
