{ pkgs, ... }:
{
  networking.vlans.wifi-3 = {
    id = 3;
    interface = "enp2s0f0";
  };
  networking.bridges.br0.interfaces = ["wifi-3"];

  systemd.network.networks."40-wifi-3".networkConfig.LinkLocalAddressing = "no";
 
  systemd.services.shorewall.serviceConfig = let
    update-ebtables = pkgs.writeShellScript "update-ebtables" ''
      set -e
      export PATH="${pkgs.iptables}/bin:$PATH"
      echo "Setting rules for ebtables..."
      ebtables -P FORWARD DROP
      ebtables -P INPUT ACCEPT
      ebtables -P OUTPUT ACCEPT
      ebtables -N drop 2>/dev/null || ebtables -F drop
      ebtables -A drop --log --log-prefix "bridge DROP: " --log-level 6 --log-ip --log-arp --limit 100/min
      ebtables -A drop -j DROP
      ebtables -N filter 2>/dev/null || ebtables -F filter
      # 0x0800 is IPv4, which we cannot write as a name because we are missing /etc/ethertypes.
      ebtables -A filter -i wifi-3 --proto 0x0806 -j ACCEPT  # ARP
      ebtables -A filter -i wifi-3 --proto 0x0800 --ip-src 192.168.89.0/24 --ip-dst 192.168.89.0/24 -j ACCEPT
      ebtables -A filter -i wifi-3 --proto 0x0800 \
        --ip-proto udp --ip-src 0.0.0.0 --ip-sport 68 \
        --ip-dst 255.255.255.255 --ip-dport 67 \
        --log --log-prefix "wifi-3 DHCP: " -j ACCEPT
      # silently drop some that are sent regularly
      ebtables -A filter -i wifi-3 --proto 0x0800 --ip-proto udp --ip-dport 123 -j DROP  # NTP
      #ebtables -A filter -i wifi-3 --proto 0x0800 --ip-proto udp --ip-dst 239.0.0.0/8 -j DROP
      # Oh, well, we have to enter the IP in Bambu Studio but it still won't work without multicast :-/
      ebtables -A filter -i wifi-3 --proto 0x0800 --ip-proto udp --ip-dst 239.255.255.0/24 -j ACCEPT
      ebtables -A filter -i wifi-3 --proto 0x0800 --ip-proto udp --ip-dst 255.255.255.255 --ip-dport 2021 -j ACCEPT
      ebtables -A filter -i wifi-3 -j drop
      ebtables -A filter -j ACCEPT
      ebtables -F FORWARD
      ebtables -A FORWARD -j filter
      ebtables -F INPUT
      ebtables -A INPUT -j filter
      echo "Setting rules for ebtables... done"
    '';
  in {
    ExecStartPost = [ update-ebtables ];
    ExecReload = [ update-ebtables ];
  };
}
