{ config, withFlakeInputs, lib, private, ... }:
{
  imports = [ (withFlakeInputs ./snowball-vm.nix) ];

  networking.externalIp = lib.fileContents "${private}/serverExternalIp.txt";

  networking.interfaces.ens3.ipv4.addresses = [ {
    address = config.networking.upstreamIp;
    prefixLength = 25;
  } ];
  networking.useDHCP = false;

  networking.defaultGateway = "192.168.84.129";
  networking.nameservers = [ "62.210.16.6" "62.210.16.7" ];
}
