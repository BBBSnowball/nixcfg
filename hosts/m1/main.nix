{ config, pkgs, lib, rockpro64Config, routeromen, withFlakeInputs, privateForHost, nixos-m1, ... }@args:
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
      desktop.default
      #tinc-client-a  #FIXME
      vscode
      ssh-github
      xonsh
      flir
      allowUnfree
    ] ++
    [ ./hardware-configuration.nix
      nixos-m1.nixosModules.apple-silicon-support
      ./users.nix
    ];

  hardware.asahi = {
    peripheralFirmwareDirectory = "${privateForHost}/asahi-firmware";
    # slower but better compatibility
    #use4KPages = true;
  };

  networking.hostName = "m1";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  #networking.useNetworkd = true;
  #systemd.network.wait-online.anyInterface = true;  # WiFi or ethernet is fine - we don't need both
  # -> We are using NetworkManger to manage network.

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
