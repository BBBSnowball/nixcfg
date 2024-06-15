{ lib, pkgs, config, ... }:
let
  ourIp = "192.168.190.29";
  dhcpRange = "192.168.190.49,192.168.190.62,255.255.255.0";
  iface = "enp193s0f3u2u3";
  mitmPort = 8080;
in
{
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    extraConfig = ''
      # Make it fast, no reason to be considerate towards other servers on our two-device network.
      # -> well, that was for network over USB.
      #dhcp-authoritative
      #dhcp-rapid-commit
      #no-ping

      log-dhcp

      #enable-tftp=${iface}
      #tftp-root=/tftpboot
      #tftp-port-range=10000,10100

      # be able to run in parallel with libvirt's dnsmasq
      #FIXME dnsmasq refuses to start because "unknown interface enp0s13f0u3u4" - but the interface exists. Well, that's a problem for later.
      interface=${iface}
      bind-interfaces

      dhcp-range=interface:${iface},${dhcpRange},10h
  
      #dhcp-option=option:router
      dhcp-option=option:router,${ourIp}

      listen-address = ${ourIp}
    '';
  };

  networking.firewall.interfaces.${iface} = {
    allowedUDPPorts = [ 53 67 69 ];
    allowedUDPPortRanges = [ { from = 10000; to = 10100; } ];
    allowedTCPPorts = [ mitmPort ];
  };

  systemd.targets.mitm = {
    description = "Serve DHCP with mitmproxy on ${iface}";
  };

  systemd.services.dnsmasq = {
    bindsTo = [ "sys-subsystem-net-devices-${iface}.device" ];
    after = [ "sys-subsystem-net-devices-${iface}.device" ];
    # don't start it by default because it would wait for the device
    # ... and we usually don't want to start it (depends on how we use the network)
    wantedBy = lib.mkForce [ "mitm.target" ];

    serviceConfig.RestartSec = 5;
  };

  systemd.services.mitmproxy = {
    description = "mitmproxy";
    wantedBy = [ "mitm.target" ];

    # set home directory so mitmproxy will be able to generate a certificate
    # -> /var/lib/mitmproxy/.mitmproxy/mitmproxy-ca-cert.pem
    # https://docs.mitmproxy.org/stable/concepts-certificates/
    # https://askubuntu.com/questions/73287/how-do-i-install-a-root-certificate/94861#94861
    #
    # Install on target:
    #     mkdir /usr/local/share/ca-certificates/extra
    #     vi /usr/local/share/ca-certificates/extra/mitmproxy-ca-cert.pem
    #     openssl x509 -in /usr/local/share/ca-certificates/extra/mitmproxy-ca-cert.pem -inform PEM -out /usr/local/share/ca-certificates/extra/mitmproxy-ca-cert.crt
    #       -> That doesn't seem to change anything. It might work if we simply rename it to .crt.
    #     update-ca-certificates   # -> "1 added"
    environment.HOME = "%S/mitmproxy";

    serviceConfig = {
      DynamicUser = true;
      User = "mitmproxy";
      StateDirectory = "mitmproxy";
      ExecStartPre = "${pkgs.coreutils}/bin/chmod 0700 %S/mitmproxy";
      #ExecStart = "${pkgs.mitmproxy}/bin/mitmweb --no-web-open-browser --listen-host ${ourIp} --listen-port ${toString mitmPort} --save-stream-file $STATE_DIRECTORY/mitmproxy.dump";
      ExecStart = "${pkgs.mitmproxy}/bin/mitmweb --no-web-open-browser --listen-host ${ourIp} --listen-port ${toString mitmPort} --save-stream-file %S/mitmproxy/mitmproxy.dump --map-local '|.*/UGOSPRO_OTA_1.0.0.0851-release-0611.img|/var/lib/mitmproxy/UGOSPRO_OTA_1.0.0.0851-release-0611.img'";
    };
  };

  systemd.services.mitm-iptables = {
    description = "mitmproxy";
    wantedBy = [ "mitm.target" ];

    serviceConfig = {
      Type = "oneshot";
    };

    path = [ pkgs.iptables pkgs.procps ];
    # https://docs.mitmproxy.org/stable/howto-transparent/
    script = ''
      iptables -P FORWARD DROP
      sysctl -w net.ipv4.ip_forward=1
      #sysctl -w net.ipv6.conf.all.forwarding=1
      #sysctl -w net.ipv4.conf.all.send_redirects=0
      iptables -t nat -A PREROUTING -i ${iface} -p tcp --dport 80 -j REDIRECT --to-port 8080
      iptables -t nat -A PREROUTING -i ${iface} -p tcp --dport 443 -j REDIRECT --to-port 8080
    '';
  };
}
