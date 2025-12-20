{ config, pkgs, lib, rockpro64Config, routeromen, withFlakeInputs, privateForHost, secretForHost, nixpkgs-mongodb, ... }@args:
let                                                                                                 
  modules = args.modules or (import ./modules.nix {});
in
{
  imports =
    with routeromen.nixosModules; [
      snowball-headless-big
      raspi-zero-usbboot
      raspi-pico
      network-manager
      desktop-base
      tinc-client
      tinc-client-a
      vscode
      omada-controller
    ] ++
    [ ./hardware-configuration.nix
      ./rust.nix
      ./udev.nix
      #./3dprint.nix
      ./xrdp.nix
      ./brother_ql/brother_ql_driver.nix
      ./brother_ql/brother_ql_service.nix
      ./iperf3.nix
      ./virtmanager.nix
      ./test-zigbee.nix
      ./smokeping.nix
    ];

  disabledModules = [ "services/networking/xrdp.nix" ];

  networking.hostName = "gk3v-pb";
  networking.domain = "fritz.box";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;    
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  networking.useDHCP = false;

  networking.interfaces."tinc.bbbsnowbal".ipv4.addresses = [ {
    address = "192.168.84.55";
    prefixLength = 24;
  } ];
  networking.interfaces."tinc.a".ipv4.addresses = [ {
    address = "192.168.83.55";
    prefixLength = 24;
  } ];

  users.users.user = {
    isNormalUser = true;
    hashedPasswordFile = "${secretForHost}/rootpw";
    extraGroups = [ "dialout" "wheel" ];
    openssh.authorizedKeys.keyFiles = [ "${privateForHost}/ssh-laptop.pub" ];

    packages = (with pkgs; [
      # GraphViz is used for dependency tree in FreeCAD.
      #cura freecad kicad graphviz blender
      firefox pavucontrol chromium
      mplayer mpv vlc
      speedcrunch
      libreoffice gimp
      x11vnc
      #vscodium
      vscode  # We need MS C++ Extension for PlatformIO.
      python3 # for PlatformIO
      #platformio  # would be a different version than that in VS Code
      w3m
      kupfer
      nfs-utils
      printrun # pronterface
    ]) ++ (with pkgs.gnome; with pkgs; [
      # Avoid warning in 24.11 by not accessing them through pkgs.gnome when possible.
      eog
      evince
      cheese
      gnome-screenshot
    ]);
  };
  users.users.root = {
    # generate contents with `mkpasswd -m sha-512`
    hashedPasswordFile = "${secretForHost}/rootpw";

    openssh.authorizedKeys.keyFiles = [ "${privateForHost}/ssh-laptop.pub" ];
  };

  services.xrdp.enable = true;
  services.xrdp.extraConfig = ''
    [ExistingVNC]
    name=Existing VNC
    lib=libvnc.so
    port=ask5900
    username=na
    password=ask
    ip=127.0.0.1
  '';
  networking.firewall.allowedTCPPorts = [
    config.services.xrdp.port
    657 # Tinc
  ];
  networking.firewall.allowedUDPPorts = [ 657 ];  # Tinc

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    inetutils  # telnet
    #nix-output-monitor
    mbuffer brotli zopfli
    tree
  ];

  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];

  nix.registry.routeromen.flake = routeromen;

  # desktop stuff
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  services.rpcbind.enable = true;  # for NFS client

  services.tailscale.enable = true;
  #networking.networkmanager.unmanaged = [ "interface-name:tailscale0" "interface-name:tinc.*" "interface-name:vnet*" "interface-name:lo" ];
  networking.networkmanager.unmanaged = [ "interface-name:tailscale0" "interface-name:tinc.*" "interface-name:vnet*" ];
  # If wait-online service hangs, enable debug loglevel and run this:
  # journalctl --unit NetworkManager.service --since "-10min" --grep startup; nmcli c s -a
  #networking.networkmanager.logLevel = "DEBUG"; # or "TRACE";
  #systemd.services.NetworkManager-wait-online.serviceConfig.Environment = "NM_ONLINE_TIMEOUT=10";
  # -> Well, I give up. See https://github.com/NixOS/nixpkgs/issues/180175
  systemd.services.NetworkManager-wait-online.enable = false;

  # avoid warnings: "portmapper: failed to get PCP mapping: PCP is implemented but not enabled in the router"
  # see https://github.com/tailscale/tailscale/issues/13145
  systemd.services.tailscaled.environment.TS_DISABLE_PORTMAPPER = "1";

  #services.omada-controller.mongodbPackage = nixpkgs-mongodb.legacyPackages.x86_64-linux.mongodb;
  #services.omada-controller.mongodbPackage = (import nixpkgs-mongodb { system = "x86_64-linux"; config.allowUnfree = true; }).mongodb;
  services.omada-controller.mongodbNixpkgs = nixpkgs-mongodb;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?
}
