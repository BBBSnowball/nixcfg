{ config, pkgs, ... }:
let
  self = config.networking.hostName;
  downstreamIP = (builtins.head config.networking.interfaces.br0.ipv4.addresses).address;
  routerIP = "192.168.89.3";
in
{
  # 67 is DHCP, 69 is TFTP
  networking.firewall.interfaces.br0.allowedTCPPorts = [ 69 ];
  networking.firewall.interfaces.br0.allowedUDPPorts = [ 67 69 ];

  services.shorewall.rules = {
    dhcp-server-tcp = {
      proto = "tcp";
      destPort = [ 69 ];
    };
    dhcp-server-dup = {
      proto = "udp";
      destPort = [ 67 69 ];
    };
  };

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
      conf-file=/etc/nixos/private/by-host/routeromen/dhcp-static-hosts.conf
    '';
  };
}
