{ config, pkgs, lib, routeromen, private, withFlakeInputs, ... }:

let
  privateForHost = "${private}/by-host/${config.networking.hostName}";
  privateInitrd = import "${privateForHost}/initrd.nix" { testInQemu = false; };
  privateValues = import privateForHost;

  serverExternalIp = config.networking.externalIp;
in {
  imports =
    [ (withFlakeInputs ../sonline0-initrd/main.nix)
      #namedFirewallPorts
      ./firewall-iptables-restore-simple.nix
      routeromen.nixosModules.snowball-headless
      ./vms.nix
      ./kexec.nix
    ];

  boot.loader.grub.devices = [
    "/dev/sda"
    "/dev/sdb"
    "/dev/sdc"
  ];
  boot.loader.grub.extraInstallCommands = ''
  '';

  environment.systemPackages = with pkgs; [
    iptables
  ];

  #networking.firewall.enable = true;
  networking.firewall.iptables-restore.enable = true;
  services.openssh.ports = [ privateInitrd.port ];

  boot.kernel.sysctl."net.ipv4.ip_forward" = "1";

  users.mutableUsers = false;
  # generate contents with `mkpasswd -m sha-512`
  users.users.root.passwordFile = "/etc/nixos/secret/by-host/${config.networking.hostName}/rootpw";
  users.users.${privateValues.userName} = {
    isNormalUser = true;
    openssh.authorizedKeys.keyFiles = [
      "${privateForHost}/ssh-laptop.pub"
      "${privateForHost}/ssh-routeromen.pub"
    ];
    extraGroups = [ "wheel" ];
  };
  users.users.portfwd = {
    isNormalUser = true;
  };
  users.users.test = {
    isNormalUser = true;
  };
  security.sudo = {
    enable = true;
    execWheelOnly = true;
    wheelNeedsPassword = false;
  };
  #nix.settings.trusted-users = [ "root" "@wheel" ];
  nix.settings.trusted-public-keys = privateValues.trusted-public-keys;

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "22.11"; # Did you read the comment?
}
