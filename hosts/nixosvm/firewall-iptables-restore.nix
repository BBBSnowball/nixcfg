{ ... }:
{
  imports = [
    ./firewall-iptables-restore
  ];

  networking.firewall.iptables-restore.enable = true;

  #FIXME This is *UGLY*. I should change to a iptables-restore based flow asap.
  #      NixOS has an issue for that but that has been open for years:
  #      https://github.com/NixOS/nixpkgs/issues/4155
#  networking.firewall.extraCommands = lib.mkIf (! config.networking.firewall.iptables-restore.enable) ''
#    iptables -w -F FORWARD
#    iptables -w -F fw-reject || true
#    iptables -w -X fw-reject || true
#    iptables -w -N fw-reject
#    iptables -w -A fw-reject -m limit --limit 10/minute --limit-burst 5 -j LOG --log-prefix "refused forward: " --log-level 6
#    iptables -w -A fw-reject -j REJECT
#    iptables -w -A FORWARD -i vpn_android-+ -o tinc.bbbsnowbal -p tcp -d 192.168.84.36 --dport 443 -j ACCEPT  # calendar
#    iptables -w -A FORWARD -o vpn_android-+ -i tinc.bbbsnowbal -p tcp -s 192.168.84.36 --sport 443 -j ACCEPT
#    iptables -w -A FORWARD -i vpn_android-+ -o tinc.bbbsnowbal -p tcp -d 192.168.84.47 --dport 80 -j ACCEPT  # fhem
#    iptables -w -A FORWARD -o vpn_android-+ -i tinc.bbbsnowbal -p tcp -s 192.168.84.47 --sport 80 -j ACCEPT
#    iptables -w -A FORWARD -i vpn_+ -o ens3 -d 192.168.0.0/16,127.0.0.0/8 -j fw-reject
#    iptables -w -A FORWARD -i vpn_+ -o ens3 -j ACCEPT
#    iptables -w -A FORWARD -o vpn_+ -i ens3 -j ACCEPT
#    iptables -w -A FORWARD -j fw-reject
#    iptables -w -t nat -F POSTROUTING
#    iptables -w -t nat -A POSTROUTING -o ens3 -j MASQUERADE
#    ip6tables -w -F FORWARD
#    ip6tables -w -A FORWARD -j REJECT
#
#    iptables -w -t nat -F PREROUTING
#    iptables -w -t nat -A PREROUTING -i vpn_android-+ -d 192.168.112.10/32 -p tcp --dport 80 -j DNAT --to-destination ${upstreamIP}:${toString ports.rss.port}
#    iptables -w -t nat -A PREROUTING -i vpn_android-+ -d 192.168.118.10/32 -p tcp --dport 80 -j DNAT --to-destination ${upstreamIP}:${toString ports.notes-magpie-ext.port}
#    # Dummy port, copied from old VPN on kim: 1743 on public IP of Kim is redirected to 443 on gallery for access to Davical/calendar
#    iptables -w -t nat -A PREROUTING -i vpn_android-+ -s 192.168.88.0/23 -d 37.187.106.83/32 -p tcp --dport 1743 -j DNAT --to-destination 192.168.84.36:443
#    iptables -w -t nat -I POSTROUTING -s 192.168.88.0/23 -d 192.168.84.36/32 -o tinc.bbbsnowbal -j MASQUERADE  # adjust source IP so tinc can handle the packets
#    iptables -w -t nat -A PREROUTING -i vpn_android-+ -s 192.168.91.0/23 -d 37.187.106.83/32 -p tcp --dport 1743 -j DNAT --to-destination 192.168.84.36:443
#    iptables -w -t nat -I POSTROUTING -s 192.168.91.0/23 -d 192.168.84.36/32 -o tinc.bbbsnowbal -j MASQUERADE  # adjust source IP so tinc can handle the packets
#
#    #TODO The second rule is required for the first rule to work and we need a route on bbverl:
#    # route add -host 192.168.88.2 gw 192.168.84.37
#    #allow_port_forward(in_iface, "bbbsnowball-dev", "192.168.84.47", :tcp, 80)
#    #dnat_port_forward(in_iface, "192.168.85.47", :tcp, 80, "bbbsnowball-dev", "192.168.84.47", 80)
#    iptables -w -t nat -A PREROUTING -i vpn_android-+ -s 192.168.88.0/23 -d 192.168.85.47/32 -p tcp --dport 80 -j DNAT --to-destination 192.168.84.47:80
#    iptables -w -t nat -I POSTROUTING -s 192.168.88.0/23 -d 192.168.84.47/32 -o tinc.bbbsnowbal -j MASQUERADE  # adjust source IP so tinc can handle the packets
#
#    #TODO We shoud properly filter incoming packets from VPN: deny from vpn_+ in INPUT, allow "--icmp-type destination-unreachable", whitelist appropriate ports
#    #TODO This should already be rejected in FORWARD but this is not logged and connection times out instead.
#    iptables -w -t nat -A PREROUTING -i vpn_+ -d 192.168.0.0/16 -p tcp -j DNAT --to-destination 127.0.0.2:1
#    iptables -w -t nat -A PREROUTING -i vpn_+ -d 192.168.0.0/16 -p udp -j DNAT --to-destination 127.0.0.2:1
#  '';
  networking.firewall.iptables.tables = {
    filter.FORWARD.policy = "DROP";
    filter.FORWARD.rules.vpn.rules4 = ''
      # calendar
      -i vpn_android-+ -o tinc.bbbsnowbal -p tcp -d 192.168.84.36 --dport 443 -j ACCEPT
      -o vpn_android-+ -i tinc.bbbsnowbal -p tcp -s 192.168.84.36 --sport 443 -j ACCEPT
      # fhem
      -i vpn_android-+ -o tinc.bbbsnowbal -p tcp -d 192.168.84.47 --dport 80 -j ACCEPT
      -o vpn_android-+ -i tinc.bbbsnowbal -p tcp -s 192.168.84.47 --sport 80 -j ACCEPT
      -i vpn_+ -o ens3 -d 192.168.0.0/16,127.0.0.0/8 -j fw-reject
      -i vpn_+ -o ens3 -j ACCEPT
      -o vpn_+ -i ens3 -j ACCEPT
    '';
    filter.FORWARD.rules.reject.order = 200;
    filter.FORWARD.rules.reject.rules4 = ''
      -j fw-reject
    '';
    filter.fw-reject.rules.default.rules = ''
      -m limit --limit 10/minute --limit-burst 5 -j LOG --log-prefix "refused forward: " --log-level 6
      -j REJECT
    '';
    filter.FORWARD.rules.reject.rules6 = ''
      -j REJECT
    '';

    nat.POSTROUTING.rules.nat.rules4 = ''
      -o ens3 -j MASQUERADE
    '';
    nat.POSTROUTING.rules.nat.order = 200;

#    nat.PREROUTING.rules.vpn.rules4 = ''
#      -i vpn_android-+ -d 192.168.112.10/32 -p tcp --dport 80 -j DNAT --to-destination ${upstreamIP}:${toString ports.rss.port}
#      -i vpn_android-+ -d 192.168.118.10/32 -p tcp --dport 80 -j DNAT --to-destination ${upstreamIP}:${toString ports.notes-magpie-ext.port}
#      # Dummy port, copied from old VPN on kim: 1743 on public IP of Kim is redirected to 443 on gallery for access to Davical/calendar
#      -i vpn_android-+ -s 192.168.88.0/23 -d 37.187.106.83/32 -p tcp --dport 1743 -j DNAT --to-destination 192.168.84.36:443
#      -i vpn_android-+ -s 192.168.91.0/23 -d 37.187.106.83/32 -p tcp --dport 1743 -j DNAT --to-destination 192.168.84.36:443
#    '';
    nat.POSTROUTING.rules.vpn.rules4 = ''
      # adjust source IP so tinc can handle the packets
      -s 192.168.88.0/23 -d 192.168.84.36/32 -o tinc.bbbsnowbal -j MASQUERADE  
      -s 192.168.91.0/23 -d 192.168.84.36/32 -o tinc.bbbsnowbal -j MASQUERADE
    '';

    nat.PREROUTING.rules.fwd-bbverl.rules4 = ''
      #TODO The second rule is required for the first rule to work and we need a route on bbverl:
      # route add -host 192.168.88.2 gw 192.168.84.37
      #allow_port_forward(in_iface, "bbbsnowball-dev", "192.168.84.47", :tcp, 80)
      #dnat_port_forward(in_iface, "192.168.85.47", :tcp, 80, "bbbsnowball-dev", "192.168.84.47", 80)
      -i vpn_android-+ -s 192.168.88.0/23 -d 192.168.85.47/32 -p tcp --dport 80 -j DNAT --to-destination 192.168.84.47:80
    '';
    nat.POSTROUTING.rules.fwd-bbverl.rules4 = ''
      # adjust source IP so tinc can handle the packets
      -s 192.168.88.0/23 -d 192.168.84.47/32 -o tinc.bbbsnowbal -j MASQUERADE
    '';

    nat.PREROUTING.rules.vpn-deny.order = 100;
    nat.PREROUTING.rules.vpn-deny.rules4 = ''
      #TODO We shoud properly filter incoming packets from VPN: deny from vpn_+ in INPUT, allow "--icmp-type destination-unreachable", whitelist appropriate ports
      #TODO This should already be rejected in FORWARD but this is not logged and connection times out instead.
      -i vpn_+ -d 192.168.0.0/16 -p tcp -j DNAT --to-destination 127.0.0.2:1
      -i vpn_+ -d 192.168.0.0/16 -p udp -j DNAT --to-destination 127.0.0.2:1
    '';
  };
}
