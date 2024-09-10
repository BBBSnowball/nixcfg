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

  #networking.nameservers = [ "127.0.0.1" ];

  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      interface = "br0";
      dhcp-range = "set:eth0,192.168.89.100,192.168.89.200";
      dhcp-option = [
        "option:router,${routerIP}"
        "option:dns-server,${routerIP}"
        #"66,\"192.168.89.110\""  # for PXE
      ];
      except-interface = "lo";
      listen-address = [
        downstreamIP
        "127.0.0.1"
        "127.0.0.53"
      ];
      dhcp-authoritative = true;

      enable-tftp = true;
      tftp-root = "/var/lib/tftpboot";

      # if the clients are bios, give them a bios boot file. Everyone else (because
      # many UEFI vendors send bogus Architecture numbers) gets UEFI.
      dhcp-match = "set:bios,60,PXEClient:Arch:00000";
      dhcp-boot = [
        "pxelinux.0"
        "grub/bootx64.efi,${self}"
        "tag:bios,grub/booti386,${self}"
      ];

      # static IPs are defined in this file
      conf-file = "${privateForHost}/dhcp-static-hosts.conf";


      # DNS config
      resolv-file = "/etc/ppp/resolv.conf";
      #dnssec = true;
      conntrack = true;

      # most of this is copied from OpenWRT
      domain-needed = true;  # don't lookup name without domain part on upstream servers
      server = [ "/lan/" ];   # dito for *.lan
      bogus-priv = true;     # dito for reverse dns of private IPs
      localise-queries = true;
      #read-ethers = true;
      expand-hosts = true;
      local-service = true;
      domain = "lan";
      stop-dns-rebind = true;
      rebind-localhost-ok = true;
      rebind-domain-ok = "/" + (lib.concatStringsSep "/" (with privateForHost; [trueDomain infoDomain])) + "/";
      dhcp-broadcast = "tag:needs-broadcast";
    };
  };

  systemd.services.dnsmasq.serviceConfig.StateDirectory = "dnsmasq";
  # resolved listens only on certain IPs but it conflicts with dnsmasq's ports
  # It does work if we start dnsmasq first.
  # -> Well, except systemd-resolve will not open its own socket, now. That breaks any software that trusts
  #    resolved's entry in resolv.conf. D'oh!
  # -> Let dnsmasq listen on 127.0.0.53, so it will replace resolved. Not ideal but we don't have many options here.
  #systemd.services.dnsmasq.before = [ "systemd-resolved.service" ];
  systemd.services.systemd-resolved = {
    after = [ "dnsmasq.service" ];
    wants = [ "dnsmasq.service" ];
    # stop resolved if dnsmasq is stopped (or restarted)
    partOf = [ "dnsmasq.service" ];

    # If resolved is started, some software will try to talk to it but it is broken because of dnsmasq.
    # Therefore, don't start it. Normal name resolution will work (but resolvectl will fail, of course).
    enable = false;
  };
  # avoid `after` dependency in the other direction
  # (direct, as well as via network.target)
  systemd.services.dnsmasq.after = lib.mkForce [];
}
