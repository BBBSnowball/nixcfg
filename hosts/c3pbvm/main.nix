{ config, pkgs, lib, routeromen, privateForHost, withFlakeInputs, ... }:
{
  imports =
    with routeromen.nixosModules;
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (withFlakeInputs ./c3pb)
      extra-container
      auto-upgrade
      snowball-vm-sonline0
      nixcfg-sync
      ssh-github
      #./chatgpt-telegram-bot.nix
    ];

  users.users.root.openssh.authorizedKeys.keyFiles = let
    p = "${privateForHost}/../sonline0-shared";
  in [
    "${p}/ssh-laptop.pub"
    "${p}/ssh-dom0.pub"
    "${p}/ssh-routeromen.pub"
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
