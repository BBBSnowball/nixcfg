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
      omada-controller
    ] ++
    [ ./backup.nix
      ./disko.nix
      ./hardware-configuration.nix
      ./homeautomation.nix
      ./mail.nix  #FIXME use our sendmail module
      ./monitoring.nix
      nixos-hardware.nixosModules.common-cpu-intel
      ./print-ip.nix
      ./users.nix
      ./vaultwarden.nix
      ./virtmanager.nix
      ./web.nix
    ];

  networking.hostName = "bettina-home";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.memtest86.enable = true;
  nixpkgs.allowUnfreeByName = [
    "memtest86-efi"
  ];

  # Avoid seed being stored in word accessible location. These are the bootctl warnings for this:
  #   Mount point '/boot' which backs the random seed file is world accessible, which is a security hole!
  #   Random seed file '/boot/loader/random-seed' is world accessible, which is a security hole!
  # see https://forum.endeavouros.com/t/bootctl-install-outputs-some-warnings-about-efi-mount-point-and-random-seed-file-in-the-terminal/43991/6
  fileSystems."/boot".options = [
    "fmask=0137,dmask=0027"
  ];

  networking.useNetworkd = true;
  networking.useDHCP = false;

  # WIFI is "unmanaged" (NetworkManager) and all other won't necessarily be online.
  #FIXME necessary here?
  #boot.initrd.systemd.network.wait-online.timeout = 1;
  #boot.initrd.systemd.network.wait-online.enable = false;
  #systemd.services.systemd-networkd-wait-online.serviceConfig.ExecStart = lib.mkForce [ "" "${pkgs.coreutils}/bin/true" ];

  networking.interfaces."tinc.a".ipv4.addresses = [ {
    address = tinc-a-address;
    prefixLength = 24;
  } ];

  systemd.network.wait-online.ignoredInterfaces = [ "tinc.a" ];


  networking.bridges.br0.interfaces = [ "enp1s0" ];
  networking.interfaces.br0 = {
    useDHCP = true;

    # default MAC address may be random or one of the virtual interfaces
    # so we set an explicit one (which is the same as the physical interface)
    # https://superuser.com/a/1725894
    # (For some reason, the MAC was different from that even when there was
    # only one interface.)
    macAddress = privateForHost.macAddress;
  };

  # add static IP in addition to DHCP
  # (see https://superuser.com/a/1008200)
  systemd.network.networks."40-br0".addresses = [ {
    Label = "br0:0";
    Address = "172.18.18.1/28";
  } {
    Label = "br0:1";
    Address = "192.168.2.11/24";
  } ];

  # We want to use IP 172.18.18.1 from HomeAssistant but we cannot tell HAOS
  # about the route. Therefore, we resort to some trickery: The packet will
  # be sent to the gateway but we can intercept it on the bridge and fixup
  # the target MAC address. The return packet will be fine because our host
  # does know about the route.
  #NOTE We disable it, for now, because it doesn't seem to work anymore and it breaks communication between the host and the switch.
  networking.firewall.extraCommands = ''
    ebtables -t nat -D PREROUTING -p ipv4 --ip-destination 172.18.18.1 -j dnat --dnat-target ACCEPT --to-destination '${privateForHost.macAddress}' &>/dev/null || true
    #ebtables -t nat -I PREROUTING -p ipv4 --ip-destination 172.18.18.1 -j dnat --dnat-target ACCEPT --to-destination '${privateForHost.macAddress}'
  '';

  services.tailscale.enable = true;

  nix.registry.routeromen.flake = routeromen;

  # desktop stuff
  #services.xserver.desktopManager.xfce.enable = true;

  hardware.graphics.enable = true;
  # create /etc/X11/xkb for `localectl list-x11-keymap-options`
  # https://github.com/NixOS/nixpkgs/issues/19629#issuecomment-368051434
  services.xserver.exportConfiguration = true;

  services.xserver.displayManager.lightdm.enable = false;

  programs.git.enable = true;

  environment.systemPackages = with pkgs; [
    virt-manager
    tcpdump
    lshw
    pwgen
  ];

  services.fwupd.enable = true;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}
