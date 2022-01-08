{ config, pkgs, lib, rockpro64Config, routeromen, withFlakeInputs, ... }@args:
let                                                                                                 
  modules = args.modules or (import ./modules.nix {});
in
{
  imports =
    with routeromen.nixosModules; [
      snowball-headless-big
    ] ++
    [ ./hardware-configuration.nix
    ];

  networking.hostName = "hetzner-temp";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;    
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  networking.useDHCP = true;

  users.users.user = {
    isNormalUser = true;
    openssh.authorizedKeys.keyFiles = [ ./ssh-key.txt ];
  };
  users.users.root = {
    openssh.authorizedKeys.keyFiles = [ ./ssh-key.txt ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    mosh
  ];

  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];

  nix.registry.routeromen.flake = routeromen;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}
