{ config, pkgs, lib, rockpro64Config, routeromen, withFlakeInputs, private, nixos-m1, ... }@args:
let
  modules = args.modules or (import ./modules.nix {});
  #tinc-a-address = "192.168.83.139";
in
{
  imports =
    with routeromen.nixosModules; [
      snowball-headless-big
      snowball-desktop
      network-manager
      desktop-base
      #tinc-client-a  #FIXME
      vscode
      ssh-github
      xonsh
      flir
      allowUnfree
    ] ++
    [ ./hardware-configuration.nix
      "${nixos-m1}/nix/m1-support"
      ./pipewire.nix
      (import ./users.nix { inherit pkgs private; })
      ./bluetooth.nix
    ];

  hardware.asahi = {
    peripheralFirmwareDirectory = "${private}/asahi-firmware";
    # slower but better compatibility
    #use4KPages = true;
  };

  networking.hostName = "m1";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  networking.useNetworkd = true;

  networking.useDHCP = false;

  #networking.interfaces."tinc.a".ipv4.addresses = [ {
  #  address = tinc-a-address;
  #  prefixLength = 24;
  #} ];

  #services.tinc.networks.a.extraConfig = let name = "a"; in ''
  #  # tincd chroots into /etc/tinc/${name} so we cannot put the file into /run, as we usually would.
  #  # Furthermore, tincd needs write access to the directory so we make a subdir.
  #  GraphDumpFile = status/graph.dot

  #  ConnectTo=orangepi_remoteadmin
  #'';
  #systemd.services."tinc.a" = let name = "a"; in {
  #  preStart = ''
  #    ${pkgs.coreutils}/bin/install -o tinc.${name} -m755 -d /etc/tinc/${name}/status
  #  '';
  #  serviceConfig.BindPaths = [
  #    #"/etc/tinc/a/graph.dot=/run/tinc-${name}/graph.dot"
  #  ];
  #};
  # NixOS network config doesn't setup the interface if we restart the tinc daemon
  # so let's add some redundancy:
  #environment.etc."tinc/a/tinc-up" = {
  #  text = ''
  #    #!/bin/sh
  #    ${pkgs.nettools}/bin/ifconfig $INTERFACE ${tinc-a-address} netmask 255.255.255.0
  #  '';
  #  mode = "755";
  #};
  #environment.etc."tinc/a/tinc-down" = {
  #  text = ''
  #    #!/bin/sh
  #    ${pkgs.nettools}/bin/ifconfig $INTERFACE down
  #  '';
  #  mode = "755";
  #};

  nix.registry.routeromen.flake = routeromen;

  boot.binfmt.emulatedSystems = [ "x86_64-linux" ];

  # desktop stuff
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
    mako
  ];
  environment.etc."sway/config".source = ./sway-config;
  environment.etc."alacritty.yml".source = ./alacritty.yml;
  environment.etc."xdg/i3status/config".source = ./i3status.conf;
  hardware.opengl.enable = true;
  # create /etc/X11/xkb for `localectl list-x11-keymap-options`
  # https://github.com/NixOS/nixpkgs/issues/19629#issuecomment-368051434
  services.xserver.exportConfiguration = true;

  programs.git.enable = true;

  environment.systemPackages = with pkgs; [
    mumble
    picocom
    zeal
    lazygit
    clementine
    entr
    cura freecad kicad
  ];

  #services.printing.extraConf = "LogLevel debug2";

  # enabled by nixos-hardware but causes multi-second delays for login manager and swaylock
  services.fprintd.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}
