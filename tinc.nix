{ config, pkgs, ... }:
let
  upstreamIP = (builtins.head config.networking.interfaces.br0.ipv4.addresses).address;
  tincIP     = (builtins.head config.networking.interfaces."tinc.bbbsnowbal".ipv4.addresses).address;
in
{
  environment.systemPackages = [ pkgs.tinc ];

  networking.interfaces."tinc.bbbsnowbal".ipv4.addresses = [ {
    address = "192.168.84.85";
    prefixLength = 25;
  } ];

  networking.firewall.allowedTCPPorts = [ 48656 ];
  networking.firewall.allowedUDPPorts = [ 48656 ];

  services.shorewall.rules.tinc = {
    proto = "tcp,udp";
    destPort = 48656 ;
    source = "loc,net";  # also from the internet
  };

  services.tinc.networks.bbbsnowball = {
    name = "routeromen";
    listenAddress = upstreamIP;
    package = pkgs.tinc;  # the other nodes use stable so no need to use the pre-release
    interfaceType = "tap";  # must be consistent across the network
    chroot = true;
    extraConfig = ''
      AddressFamily=ipv4
      Mode=switch
      LocalDiscovery=yes
      ConnectTo=sonline
    '';
  };

  systemd.services."tinc.bbbsnowball".preStart = ''
    ${pkgs.coreutils}/bin/install -o tinc.bbbsnowball -m755 -d /etc/tinc/bbbsnowball/hosts
    ${pkgs.coreutils}/bin/install -o root -m400 /etc/nixos/secret/tinc-bbbsnowball-rsa_key.priv /etc/tinc/bbbsnowball/rsa_key.priv

    #${pkgs.coreutils}/bin/install -o tinc.bbbsnowball -m444 /etc/nixos/private/tinc-pubkeys/bbbsnowball/* /etc/tinc/bbbsnowball/hosts/
    ${pkgs.rsync}/bin/rsync -r --delete /etc/nixos/private/tinc-pubkeys/bbbsnowball/ /etc/tinc/bbbsnowball/hosts
    chmod 444 /etc/tinc/bbbsnowball/hosts/*
    chown -R tinc.bbbsnowball /etc/tinc/bbbsnowball/hosts/
  '';
}
