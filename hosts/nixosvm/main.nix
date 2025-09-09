# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, routeromen, privateForHost, withFlakeInputs, ... }:

let
  serverExternalIp = config.networking.externalIp;
  upstreamIP = config.networking.upstreamIp;
  tincIP     = (builtins.head config.networking.interfaces."tinc.bbbsnowbal".ipv4.addresses).address;

  opensshWithUnixDomainSocket = ./openssh-with-unix-socket.nix;

  namedFirewallPorts = ./named-firewall-ports.nix;
  ports = config.networking.firewall.allowedPorts;

  useNftables = true;
in {
  imports =
    with routeromen.nixosModules; [
      ./hardware-configuration.nix
      namedFirewallPorts
      auto-upgrade
      snowball-vm-sonline0
      nixcfg-sync
      ./services/headscale.nix
      ./services/openvpn.nix
      ./services/taskserver.nix
      ./services/tinc.nix
      (if useNftables then ./firewall-nftables.nix else ./firewall-iptables-restore.nix)
    ] ++ (map withFlakeInputs [
      ./containers/bunt.nix
      ./containers/c.nix
      ./containers/feg.nix
      ./containers/git.nix
      ./containers/hedgedoc.nix
      ./containers/janina-wordpress.nix
      ./containers/janina-komm-wordpress.nix
      ./containers/janina-lead-wordpress.nix
      ./containers/mate.nix
      ./containers/notes.nix
      ./containers/omas
      ./containers/rss.nix
      ./containers/php.nix
      ./containers/weechat.nix
    ]);

  users.users.root.openssh.authorizedKeys.keyFiles = let
    p = "${privateForHost}/../sonline0-shared";
  in [
    "${p}/ssh-laptop.pub"
    "${p}/ssh-dom0.pub"
    "${p}/ssh-routeromen.pub"
  ];
  # for running wp4nix etc.
  users.users.generate-files.isNormalUser = true;

  networking.interfaces."tinc.bbbsnowbal".ipv4.addresses = [ {
    address = "192.168.84.39";
    prefixLength = 25;
  } ];
  networking.interfaces."tinc.door".ipv4.addresses = [ {
    address = "192.168.19.39";
    prefixLength = 25;
  } ];
  networking.interfaces."tinc.a".ipv4.addresses = [ {
    address = "192.168.83.39";
    prefixLength = 25;
  } ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  ];


  networking.firewall.enable = true;
  networking.nftables.enable = useNftables;

  networking.firewall.allowedPortsInterfaces = [
    "ens3"
    "tinc.bbbsnowbal"
    #"vpn_android-*"
  ];

  networking.firewall.rejectPackets = true;
  networking.firewall.pingLimit = if useNftables then "100/minute burst 20 packets" else "--limit 100/minute --limit-burst 20";

  boot.kernel.sysctl."net.ipv4.ip_forward" = "1";

  networking.firewall.interfaces."tinc.bbbsnowbal".allowedUDPPortRanges = [
    # mosh
    { from = 60000; to = 61000; }
  ];

  services.tailscale.enable = true;

  # workaround for kernel bug that breaks some tests
  # https://github.com/tailscale/tailscale/issues/16966#issuecomment-3239543750
  # -> Only required while a broken kernel is booted on the build machine.
  nixpkgs.overlays = lib.mkIf true [ (_: prev: {
    tailscale = prev.tailscale.overrideAttrs (old: {
      checkFlags =
        builtins.map (
          flag:
            if prev.lib.hasPrefix "-skip=" flag
            then flag + "|^TestGetList$|^TestIgnoreLocallyBoundPorts$|^TestPoller$"
            else flag
        )
        old.checkFlags;
    });
  }) ];

  # Postgres user in container must be able to connect to Nix daemon on host.
  #nix.settings.allowed-users = lib.mkForce ["*"];
  # -> creating a compatible user should be enough, thanks to config.ids.uids.
  users.users.postgres = {
    name = "postgres";
    uid = config.ids.uids.postgres;
    group = "postgres";
    description = "PostgreSQL server user";
    #home = "${cfg.dataDir}";
    useDefaultShell = true;
  };
  users.groups.postgres.gid = config.ids.gids.postgres;

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "22.11"; # Did you read the comment?

}
