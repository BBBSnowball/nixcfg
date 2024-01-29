{ lib, pkgs, config, privateForHost, ... }:
let
  self = config.networking.hostName;
  downstreamIP = (builtins.head config.networking.interfaces.br0.ipv4.addresses).address;
  #routerIP = "192.168.89.3";
  routerIP = downstreamIP;
in
{
  # 67 is DHCP, 69 is TFTP, 53 is DNS
  networking.firewall.interfaces.br0.allowedTCPPorts = [ 69 ];
  networking.firewall.interfaces.br0.allowedUDPPorts = [ 53 67 69 ];

  services.shorewall.rules = {
    dhcp-server = {
      rules = [
        {
          proto = "tcp";
          destPort = [ 69 ];
        }
        {
          proto = "udp";
          destPort = [ 67 69 ];
        }
      ];
    };
    dns = {
      rules = [
        {
          proto = "tcp";
          destPort = [ 53 ];
        }
        {
          proto = "udp";
          destPort = [ 53 ];
        }
      ];
    };
  };

  networking.nameservers = [ "127.0.0.1" ];

  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    extraConfig = ''
      interface=br0
      dhcp-range=set:eth0,192.168.89.100,192.168.89.200
      dhcp-option=option:router,${routerIP}
      dhcp-option=option:dns-server,${routerIP}
      except-interface=lo
      listen-address=${downstreamIP}
      listen-address=127.0.0.1
      dhcp-authoritative

      dhcp-boot=pxelinux.0
      #dhcp-option=66,"192.168.89.110"
      enable-tftp
      tftp-root=/var/lib/tftpboot

      # if the clients are bios, give them a bios boot file. Everyone else (because
      # many UEFI vendors send bogus Architecture numbers) gets UEFI.
      dhcp-match=set:bios,60,PXEClient:Arch:00000
      dhcp-boot=grub/bootx64.efi,${self}
      dhcp-boot=tag:bios,grub/booti386,${self}

      # static IPs are defined in this file
      conf-file=${privateForHost}/dhcp-static-hosts.conf


      # DNS config
      resolv-file=/etc/ppp/resolv.conf
      #dnssec
      conntrack

      # most of this is copied from OpenWRT
      domain-needed  # don't lookup name without domain part on upstream servers
      server=/lan/   # dito for *.lan
      bogus-priv     # dito for reverse dns of private IPs
      localise-queries
      #read-ethers
      expand-hosts
      local-service
      domain=lan
      stop-dns-rebind
      rebind-localhost-ok
      rebind-domain-ok=/${lib.concatStringsSep "/" (with privateForHost; [trueDomain infoDomain])}/
      dhcp-broadcast=tag:needs-broadcast
    '';
  };

  systemd.services.dnsmasq.serviceConfig.StateDirectory = "dnsmasq";
  # resolved listens only on certain IPs but it conflicts with dnsmasq's ports
  # It does work if we start dnsmasq first.
  #FIXME This is not enough. We have to stop resolved when we restart dnsmasq!
  systemd.services.dnsmasq.before = [ "systemd-resolved.service" ];
}
