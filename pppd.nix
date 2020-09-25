{ config, pkgs, ... }:
{
  systemd.network.networks.enp4s0.vlan = [ 7 8 ];
  networking.vlans.upstream-7 = {
    id = 7;
    interface = "enp4s0";
  };
  networking.vlans.upstream-8 = {
    id = 8;
    interface = "enp4s0";
  };

  environment.systemPackages = [ pkgs.ppp ];

  services.pppd = {
    enable = true;
    peers.upstream.config = "<will be replaced by link>";
  };

  environment.etc."ppp/peers/upstream".source = "/etc/nixos/private/secret/pppd.conf";

  #services.shorewall.rules.pppoe = {
  #  # This won't work because we need to filter ethertype which is below IP layer.
  #  proto = "0x8863,0x8864,0x880b";
  #  rules = [
  #    { dest = "modem"; source = "$FW"; }
  #    { dest = "$FW";   source = "modem"; }
  #  ];
  #};
}
