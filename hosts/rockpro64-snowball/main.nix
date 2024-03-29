# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{ config, pkgs, lib, rockpro64Config, routeromen, withFlakeInputs, ... }:
let
in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      rockpro64Config.nixosModule
      (withFlakeInputs ./ldap-to-ssh.nix)
      routeromen.nixosModules.snowball-headless-big
      ./autossh-to-subraum.nix
      ./rust.nix
      ./rockpro64-fan.nix
      routeromen.nixosModules.raspi-zero-usbboot
      routeromen.nixosModules.raspi-pico
      ./udev.nix
    ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  fileSystems."/debian".neededForBoot = true;
  boot.tmpOnTmpfs = true;

  networking.hostName = "rockpro64-snowball";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

  users.users.user = {
    isNormalUser = true;
    passwordFile = "/etc/nixos/secret/rootpw";
    extraGroups = [ "dialout" ];
  };
  users.users.root.passwordFile = "/etc/nixos/secret/rootpw";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    dtc kitty.terminfo
    telnet
    #nix-output-monitor
    mbuffer brotli zopfli
    tree
  ];

  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];

  nix.registry.routeromen.flake = routeromen;

  # Yeah, this is usually not a good idea. We need this for some binary-only
  # things, e.g. GreenPak support for ngspice.
  boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
  # Let's not build a special qemu for that - the normal one works just fine.
  boot.binfmt.registrations.x86_64-linux.interpreter = lib.mkForce "${pkgs.qemu}/bin/qemu-x86_64";

  programs.command-not-found.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?
}
