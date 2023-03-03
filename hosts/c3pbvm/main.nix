{ config, pkgs, lib, routeromen, private, withFlakeInputs, ... }:
let
  privateForHost = "${private}/by-host/${config.networking.hostName}";
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (withFlakeInputs ./c3pb)
      routeromen.nixosModules.extra-container
      routeromen.nixosModules.auto-upgrade
      routeromen.nixosModules.snowball-vm-sonline0
      routeromen.nixosModules.nixcfg-sync
    ];

  networking.upstreamIp = "192.168.84.135";
  users.users.root.openssh.authorizedKeys.keyFiles = [
    "${privateForHost}/ssh-laptop.pub"
    "${privateForHost}/ssh-dom0.pub"
    "${privateForHost}/ssh-routeromen.pub"
  ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    sqlite-interactive
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.test = {
    isNormalUser = true;
    #extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "20.09"; # Did you read the comment?

}
