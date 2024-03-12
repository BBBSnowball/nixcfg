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

    # for fhem:
    #TODO The second rule is required for the first rule to work and we need a route on bbverl:
    # route add -host 192.168.88.2 gw 192.168.84.37
    #allow_port_forward(in_iface, "bbbsnowball-dev", "192.168.84.47", :tcp, 80)
    #dnat_port_forward(in_iface, "192.168.85.47", :tcp, 80, "bbbsnowball-dev", "192.168.84.47", 80)

    content = ''
      set allow_vpn_to_tinc {
        typeof ip daddr . tcp dport
        counter
        flags constant
        comment "allow traffic from Android VPN to these hosts+ports";
        elements = {
          # calendar
          192.168.84.36 . 443,
          # fhem
          192.168.84.47 . 80
        }
      }

      set allow_vpn_to_tinc_ips {
        typeof ip daddr
        counter
        flags constant
        comment "same as allow_vpn_to_tinc but only the IPs";
        elements = {
          192.168.84.36,
          192.168.84.47
        }
      }

      map dnat_vpn_to_tinc {
        typeof ip saddr . ip daddr . tcp dport : ip daddr . tcp dport;
        counter
        flags constant, interval
        comment "DNAT mappings for Android VPN";

        elements = {
          # fhem
          192.168.88.0/23 . 192.168.85.47/32  . 80   : 192.168.84.47 . 80,
          #
          0.0.0.0/0       . 192.168.112.10/32 . 80   : ${upstreamIP} . ${toString ports.rss.port},
          0.0.0.0/0       . 192.168.118.10/32 . 80   : ${upstreamIP} . ${toString ports.notes-magpie-ext.port},
          #
          # Dummy port, copied from old VPN on kim: 1743 on public IP of Kim is redirected to 443 on gallery for access to Davical/calendar
          192.168.88.0/23 . 37.187.106.83/32  . 1743 : 192.168.84.36 . 443,
          192.168.91.0/23 . 37.187.106.83/32  . 1743 : 192.168.84.36 . 443,
        }
      }

      chain filter {
        type filter hook forward priority filter; policy drop;

        iifname "vpn_android-*" oifname "tinc.bbbsnowbal" ip daddr . tcp dport @allow_vpn_to_tinc accept
        oifname "vpn_android-*" iifname "tinc.bbbsnowbal" ip saddr . tcp sport @allow_vpn_to_tinc accept

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

        # lookup saddr+daddr+dport in map, get ip addr and port for dnat
        iifname "vpn_android-*" dnat ip addr . port to ip saddr . ip daddr . tcp dport map @dnat_vpn_to_tinc

        #TODO We shoud properly filter incoming packets from VPN: deny from vpn_+ in INPUT, allow "--icmp-type destination-unreachable", whitelist appropriate ports
        #TODO This should already be rejected in FORWARD but this is not logged and connection times out instead.
        iifname "vpn_*" ip daddr 192.168.0.0/16 ip protocol { tcp, udp } counter dnat to 127.0.0.2:1
      }

      chain nat {
        type nat hook postrouting priority srcnat;

        oifname "ens3" masquerade

        # adjust source IP so tinc can handle the packets
        oifname "tinc.bbbsnowbal" ip saddr { 192.168.88.0/23, 192.168.91.0/23 } ip daddr @allow_vpn_to_tinc_ips masquerade
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
