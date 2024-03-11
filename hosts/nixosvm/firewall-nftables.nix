{ config, ... }:
let
  serverExternalIp = config.networking.externalIp;
  upstreamIP = config.networking.upstreamIp;
  tincIP     = (builtins.head config.networking.interfaces."tinc.bbbsnowbal".ipv4.addresses).address;
  ports = config.networking.firewall.allowedPorts;
in
{
  networking.nftables.enable = true;

  networking.nftables.tables.filter = {
    #family = "ip";
    family = "inet";
    content = ''
      chain filter {
        type filter hook forward priority filter; policy drop;

        iifname "vpn_android-*" oifname "tinc.bbbsnowbal" ip daddr 192.168.84.36 tcp dport 443 accept

        # calendar
        iifname "vpn_android-*" oifname "tinc.bbbsnowbal" ip daddr 192.168.84.36 tcp dport 443 accept
        oifname "vpn_android-*" iifname "tinc.bbbsnowbal" ip saddr 192.168.84.36 tcp sport 443 accept
        # fhem
        iifname "vpn_android-*" oifname "tinc.bbbsnowbal" ip daddr 192.168.84.47 tcp dport 80 accept
        oifname "vpn_android-*" iifname "tinc.bbbsnowbal" ip saddr 192.168.84.47 tcp sport 80 accept
        iifname "vpn_*" oifname "ens3" ip daddr { 192.168.0.0/16, 127.0.0.0/8 } jump fw-reject
        iifname "vpn_*" oifname "ens3" accept
        oifname "vpn_*" iifname "ens3" accept
        jump fw-reject
      }

      chain fw-reject {
        limit rate 10/minute burst 5 packets counter log prefix "refused forward: " level info
      }

      chain nat2 {
        type nat hook prerouting priority dstnat;

        #TODO The second rule is required for the first rule to work and we need a route on bbverl:
        # route add -host 192.168.88.2 gw 192.168.84.37
        #allow_port_forward(in_iface, "bbbsnowball-dev", "192.168.84.47", :tcp, 80)
        #dnat_port_forward(in_iface, "192.168.85.47", :tcp, 80, "bbbsnowball-dev", "192.168.84.47", 80)
        iifname "vpn_android-*" ip saddr 192.168.88.0/23 ip daddr 192.168.85.47/32 tcp dport 80 counter dnat to 192.168.84.47:80

        iifname "vpn_android-*" ip daddr 192.168.112.10/32 tcp dport 80 counter dnat to ${upstreamIP}:${toString ports.rss.port}
        iifname "vpn_android-*" ip daddr 192.168.118.10/32 tcp dport 80 counter dnat to ${upstreamIP}:${toString ports.notes-magpie-ext.port}
        # Dummy port, copied from old VPN on kim: 1743 on public IP of Kim is redirected to 443 on gallery for access to Davical/calendar
        iifname "vpn_android-*" ip saddr { 192.168.88.0/23, 192.168.91.0/23 } ip daddr 37.187.106.83/32 tcp dport 1743 counter dnat to 192.168.84.36:443

        #TODO We shoud properly filter incoming packets from VPN: deny from vpn_+ in INPUT, allow "--icmp-type destination-unreachable", whitelist appropriate ports
        #TODO This should already be rejected in FORWARD but this is not logged and connection times out instead.
        iifname "vpn_*" ip daddr 192.168.0.0/16 ip protocol { tcp, udp } counter dnat to 127.0.0.2:1
      }

      chain nat {
        type nat hook postrouting priority srcnat;

        oifname "ens3" masquerade

        # adjust source IP so tinc can handle the packets
        oifname "tinc.bbbsnowbal" ip saddr { 192.168.88.0/23, 192.168.91.0/23 } ip daddr { 192.168.84.36/32, 192.168.84.47/32 } masquerade
      }
    '';
  };
  #networking.nftables.tables.filter6 = {
  #  family = "ip6";
  #  content = ''
  #    chain filter {
  #      type filter hook forward priority filter; policy drop;
  #      limit rate 10/minute burst 5 packets counter log prefix "refused forward: " level info
  #    };
  #  '';
  #};
}
