{ config, pkgs, private, ... }:
let
  upstreamIP = (builtins.head config.networking.interfaces.br0.ipv4.addresses).address;
in
{
  #imports = routeromen.nixosModules.tinc-client;
  imports = [ (import ../../modules/tinc-client-common.part.nix {
    name       = "bbbsnowball";
    extraConfig = ''
      LocalDiscovery=yes
      ConnectTo=sonline
      #ConnectTo=routeromen
    '';
  }) ];

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
    listenAddress = upstreamIP;
  };
}
