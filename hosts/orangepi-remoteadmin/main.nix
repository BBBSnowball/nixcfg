{ config, pkgs, lib, rockpro64Config, routeromen, withFlakeInputs, private, ... }:
let
  basicUser = {
    # generate contents with `mkpasswd -m sha-512`
    passwordFile = "/etc/nixos/secret/rootpw";

    openssh.authorizedKeys.keyFiles = [
      "${private}/ssh-laptop.pub"
      "${private}/ssh-framework-user.pub"
      "${private}/ssh-framework-root.pub"
    ];
  };
  rootUser = basicUser;
  normalUser = basicUser // {
    isNormalUser = true;

    packages = with pkgs; [
    ];

    extraGroups = [ "dialout" ];
  };
in {
  imports =
    [ ./orangpi-pc2.nix
      #routeromen.nixosModules.snowball-headless-big
      routeromen.nixosModules.snowball-headless
      ./orangpi-installer.nix
      ./wwan.nix
    ];

  #boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelPackages = pkgs.linuxPackages;

  boot.tmpOnTmpfs = true;

  networking.hostName = "orangepi-remoteadmin";

  system.baseUUID = builtins.readFile "${private}/baseUUID";

  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

  users.users.user = normalUser;
  users.users.root = rootUser;

  environment.systemPackages = with pkgs; [
    mosh
  ];

  # for mosh
  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];

  nix.registry.routeromen.flake = routeromen;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?
}
