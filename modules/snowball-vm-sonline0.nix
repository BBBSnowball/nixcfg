{ config, modules, privateForHost, ... }:
{
  imports = [ modules.snowball-vm ];

  networking.externalIp = privateForHost.serverExternalIp;

  networking.interfaces.ens3.ipv4.addresses = [ {
    address = config.networking.upstreamIp;
    prefixLength = 25;
  } ];
  networking.useDHCP = false;

  networking.defaultGateway = "192.168.84.129";
  networking.nameservers = [ "62.210.16.6" "62.210.16.7" ];
}
