{ config, lib, ... }:
let
  ports = config.networking.firewall.allowedPorts;
in {
  services.openvpn.servers = let
    serverExternalIp = config.networking.externalIp;
    upstreamIP = config.networking.upstreamIp;

    #FIXME use an additional IP to make one of the "cool" VPNs, i.e. UDP on 53 and TCP on 443
    #NOTE We are listening on IPv4 and IPv6 here but client won't automatically reconnect when
    #     switching to an IPv4-only net on the client side. Therefore `proto udp4` is still
    #     recommended for the client side.
    makeVpn= name: { keyName ? null, subnet, port, useTcp ? false, ... }: {
      config = ''
        dev vpn_${name}
        dev-type tun
        ifconfig 192.168.${toString subnet}.1 192.168.${toString subnet}.2
        # openvpn --genkey --secret static.key
        secret /var/openvpn/${if keyName != null then keyName else name}.key
        port ${toString port}
        #local ${serverExternalIp}
        #local ${upstreamIP}
        comp-lzo
        keepalive 300 600
        ping-timer-rem      # only for davides and jolla
        persist-tun         # not for tcp
        persist-key         # not for tcp
        cipher aes-256-cbc  # for android-udp
        ${lib.optionalString useTcp "proto tcp-server"}
        ${lib.optionalString (!useTcp) "proto udp6"}

        user  nobody
        group nogroup
      '';
    };
  in lib.attrsets.mapAttrs makeVpn {
    android-udp = { subnet = 88; port = ports.openvpn-android-udp.port; keyName = "android"; };
    android-tcp = { subnet = 91; port = ports.openvpn-android-tcp.port; keyName = "android"; useTcp = true; };
    #jolla      = { subnet = 90; port = 446; };  # not used anymore
    davides     = { subnet = 87; port = ports.openvpn-davides.port; };

    carsten-udp = { subnet = 51; port = ports.openvpn-carsten-udp.port; keyName = "carsten"; };
    carsten-tcp = { subnet = 52; port = ports.openvpn-carsten-tcp.port; keyName = "carsten"; useTcp = true; };
  };

  # must use unpriviledged port for TCP (but external port can be priviledged due to DNAT)
  # see https://gionn.net/2010/02/28/openvpn-on-a-privileged-port-with-an-unprivileged-user/
  networking.firewall.allowedPorts.openvpn-android-tcp = 4440;  # external port is 444 due to DNAT
  networking.firewall.allowedPorts.openvpn-android-udp = { type = "udp"; port = 444; };
  networking.firewall.allowedPorts.openvpn-davides     = { type = "udp"; port = 450; };
  networking.firewall.allowedPorts.openvpn-carsten-udp = { type = "udp"; port = 451; };
  networking.firewall.allowedPorts.openvpn-carsten-tcp = { type = "tcp"; port = 4510; };
}
