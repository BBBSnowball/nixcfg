{ config, pkgs, lib, rockpro64Config, routeromen, withFlakeInputs, ... }@args:
let                                                                                                 
  modules = args.modules or (import ./modules.nix {});
  private = (args.private or ./private) + /data;
  hostSpecificValue = path: import "${private}/by-host/${config.networking.hostName}${path}";
in
{
  imports =
    with routeromen.nixosModules; [
      snowball-headless-big
      raspi-zero-usbboot
      raspi-pico
      network-manager
      desktop-base
    ] ++
    [ ./hardware-configuration.nix
      ./rust.nix
      ./udev.nix
      ./3dprint.nix
    ];

  networking.hostName = "gk3v-pb";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;    
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  networking.useDHCP = false;

  users.users.user = {
    isNormalUser = true;
    passwordFile = "/etc/nixos/secret/rootpw";
    extraGroups = [ "dialout" "wheel" ];
    openssh.authorizedKeys.keyFiles = [ "${private}/ssh-laptop.pub" ];

    packages = with pkgs; [
      cura freecad kicad
      firefox pavucontrol
      mplayer mpv vlc
      speedcrunch
    ];
  };
  users.users.root = {
    # generate contents with `mkpasswd -m sha-512`
    passwordFile = "/etc/nixos/secret/rootpw";

    openssh.authorizedKeys.keyFiles = [ "${private}/ssh-laptop.pub" ];
  };

  services.xrdp.enable = true;
  networking.firewall.allowedTCPPorts = [ config.services.xrdp.port ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    telnet
    #nix-output-monitor
    mbuffer brotli zopfli
    tree
  ];

  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];

  nix.registry.routeromen.flake = routeromen;

  # desktop stuff
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?
}
