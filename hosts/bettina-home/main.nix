{ config, pkgs, lib, rockpro64Config, routeromen, withFlakeInputs, privateForHost, nixos-hardware, ... }@args:
let
  modules = args.modules or (import ./modules.nix {});
  tinc-a-address = "192.168.83.123";
in
{
  imports =
    with routeromen.nixosModules; [
      snowball-headless-big
      desktop-base
      tinc-client-a
      ssh-github
      allowUnfree
    ] ++
    [ ./hardware-configuration.nix
      ./users.nix
      ./virtmanager.nix
      #./test-zigbee.nix
    ];

  networking.hostName = "bettina-home";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.memtest86.enable = true;
  nixpkgs.allowUnfreeByName = [
    "memtest86-efi"
  ];

  networking.useNetworkd = true;
  networking.useDHCP = false;

  # WIFI is "unmanaged" (NetworkManager) and all other won't necessarily be online.
  #FIXME necessary here?
  boot.initrd.systemd.network.wait-online.timeout = 1;
  boot.initrd.systemd.network.wait-online.enable = false;
  systemd.services.systemd-networkd-wait-online.serviceConfig.ExecStart = lib.mkForce [ "" "${pkgs.coreutils}/bin/true" ];

  networking.interfaces."tinc.a".ipv4.addresses = [ {
    address = tinc-a-address;
    prefixLength = 24;
  } ];

  systemd.network.wait-online.ignoredInterfaces = [ "tinc.a" ];

  nix.registry.routeromen.flake = routeromen;

  # desktop stuff
  services.xserver.desktopManager.xfce.enable = true;

  programs.sway.enable = true;
  programs.sway.wrapperFeatures.gtk = true;
  programs.sway.extraPackages = with pkgs; [
    alacritty kitty foot dmenu kupfer
    wdisplays
    sway-contrib.grimshot
    mako
    pulseaudio
  ];
  environment.etc."sway/config".source = ./sway-config;
  environment.etc."alacritty.yml".source = ./alacritty.yml;
  hardware.opengl.enable = true;
  # create /etc/X11/xkb for `localectl list-x11-keymap-options`
  # https://github.com/NixOS/nixpkgs/issues/19629#issuecomment-368051434
  services.xserver.exportConfiguration = true;

  programs.git.enable = true;

  environment.systemPackages = with pkgs; [
    virt-manager
    tcpdump
    lshw
  ];

  services.fwupd.enable = true;

  services.openssh.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}
