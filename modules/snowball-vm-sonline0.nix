{ lib, config, modules, privateForHost, ... }:
let
  inherit (privateForHost.sonline0) serverExternalIp ipv4Net ipv6Net;
  inherit (config.networking) vmNumber;
in
{
  imports = [ modules.snowball-vm ];

  networking.externalIp = serverExternalIp;
  networking.externalIpv6 = lib.mkDefault "${ipv6Net.prefix}${toString vmNumber}";
  networking.upstreamIp = lib.mkDefault "${ipv4Net.prefix}${toString vmNumber}";
  networking.vmNumber = lib.mkIf (privateForHost ? vmNumber) privateForHost.vmNumber;

  networking.interfaces.ens3.ipv4.addresses = [ {
    address = config.networking.upstreamIp;
    prefixLength = 25;
  } ];
  networking.interfaces.ens3.ipv6.addresses = [ {
    # The VM number will be interpreted as hex here and the subnet will be larger.
    # That is on purpose because it makes it easier to see the relation.
    address = config.networking.externalIpv6;
    prefixLength = 120;
  } ];
  networking.useDHCP = false;

  networking.defaultGateway.address = "${ipv4Net.prefix}129";
  networking.defaultGateway6.address = "${ipv6Net.prefix}129";
  #networking.nameservers = [ "62.210.16.6" "62.210.16.7" ];
  networking.nameservers = [ "51.159.69.156" "51.159.69.162" ];
}
