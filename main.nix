# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, routeromen, private, withFlakeInputs, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (withFlakeInputs ./c3pb)
      routeromen.nixosModules.extra-container
      routeromen.nixosModules.auto-upgrade
      routeromen.nixosModules.snowball-vm-sonline0
    ];

  networking.upstreamIp = "192.168.84.135";
  users.users.root.openssh.authorizedKeys.keyFiles = [
    "${private}/ssh-laptop.pub"
    "${private}/ssh-dom0.pub"
    "${private}/ssh-routeromen.pub"
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
