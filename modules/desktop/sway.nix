{ lib, pkgs, config, ... }:
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
    waybar
  ];
  environment.etc."sway/config".source = ./sway-config;
  environment.etc."alacritty.yml".source = ./alacritty.yml;
  #environment.etc."i3status.conf".source = ./i3status.conf;
  environment.etc."xdg/i3status/config".source = ./i3status.conf;
  hardware.opengl.enable = true;
  # create /etc/X11/xkb for `localectl list-x11-keymap-options`
  # https://github.com/NixOS/nixpkgs/issues/19629#issuecomment-368051434
  services.xserver.exportConfiguration = true;

  # https://wiki.archlinux.org/title/sway#Manage_Sway-specific_daemons_with_systemd
  systemd.user.targets.sway-session = {
    description = "Sway compositor session";
    bindsTo = [ "graphical-session.target" ];
    wants = [ "graphical-session-pre.target" ];
    after = [ "graphical-session-pre.target" ];
  };

  programs.nm-applet.enable = true;
  
  systemd.user.services.blueman-applet = lib.mkIf config.services.blueman.enable {
    wantedBy = [ "sway-session.target" ];
    partOf = [ "sway-session.target" ];
    # already set by blueman's service file
    #description = "Bluetooth manager applet";
    #serviceConfig.ExecStart = "${pkgs.blueman}/bin/blueman-applet";
  };

  systemd.user.services.mako = {
    description = "Mako (notification daemon)";
    wantedBy = [ "sway-session.target" ];
    partOf = [ "sway-session.target" ];
    serviceConfig.ExecStart = "${pkgs.mako}/bin/mako";
  };

  systemd.user.services.swayidle = {
    description = "swayidle";
    wantedBy = [ "sway-session.target" ];
    partOf = [ "sway-session.target" ];
    path = with pkgs; [ sway swaylock playerctl ];
    serviceConfig.ExecStart = lib.escapeShellArgs [
      "${pkgs.swayidle}/bin/swayidle" "-w"
      "timeout" "300" "swaylock -f -c 000000"
      "timeout" "600" "swaymsg \"output * dpms off\""
      "resume" "swaymsg \"output * dpms on\""
      "before-sleep" "swaylock -f -c 000000; playerctl pause"
    ];
  };

  environment.etc."xdg/waybar/config".source = ./waybar/config.json;
  environment.etc."xdg/waybar/style.css".source = ./waybar/style.css;

  fonts.packages = with pkgs; [
    # fonts for waybar and other special cases
    # https://www.reddit.com/r/NixOS/comments/16i7bc0/how_to_install_powerline_and_fontawesome/
    font-awesome
    powerline-fonts
    powerline-symbols
    (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
    # https://github.com/Alexays/Waybar/issues/1486
    roboto
    #meslo-lg
    #xlsfonts

    noto-fonts-monochrome-emoji
    noto-fonts-color-emoji
    #noto-fonts
  ];

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.cpupower-gui.enable = true;
}
