{ config, pkgs, lib, rockpro64Config, routeromen, withFlakeInputs, private, ... }@args:
let                                                                                                 
  modules = args.modules or (import ./modules.nix {});
  hostSpecificValue = path: import "${private}/by-host/${config.networking.hostName}${path}";
in
{
  imports =
    with routeromen.nixosModules; [
      snowball-headless-big
      snowball-desktop
      network-manager
      desktop-base
    ] ++
    [ ./hardware-configuration.nix
    ];

  networking.hostName = "fw";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.memtest86.enable = true;
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "memtest86-efi"
    "vscode"
  ];

  networking.useDHCP = false;

  networking.interfaces."tinc.bbbsnowbal".ipv4.addresses = [ {
    address = "192.168.84.55";
    prefixLength = 24;
  } ];

  users.users.user = {
    isNormalUser = true;
    passwordFile = "/etc/nixos/secret/rootpw";
    # lp: I couldn't get the Brother QL-500 to work through cups and the
    # web interface can only do text so we have to access it directly.
    extraGroups = [ "dialout" "wheel" "lp" ];
    openssh.authorizedKeys.keyFiles = [ "${private}/ssh-laptop.pub" ];

    packages = with pkgs; [
      firefox pavucontrol chromium
      mplayer mpv
      speedcrunch
      libreoffice gimp
      gnome.eog gnome.evince
      x11vnc
      vscode  # We need MS C++ Extension for PlatformIO.
      python3 # for PlatformIO
      w3m
      kupfer
      #(git.override { guiSupport = true; })
      gnome.gnome-screenshot
    ];
  };
  users.users.root = {
    # generate contents with `mkpasswd -m sha-512`
    passwordFile = "/etc/nixos/secret/rootpw";

    openssh.authorizedKeys.keyFiles = [ "${private}/ssh-laptop.pub" ];
  };

  nix.registry.routeromen.flake = routeromen;

  # desktop stuff
  #services.xserver.displayManager.lightdm.enable = true;
  #services.xserver.desktopManager.xfce.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # for Framework laptop
  # see http://kvark.github.io/linux/framework/2021/10/17/framework-nixos.html
  boot.kernelParams = [ "mem_sleep_default=deep" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}
