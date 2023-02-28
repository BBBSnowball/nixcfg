{ lib, config, private, ... }:
{
  assertions = [ {
    assertion = config.systemd.network.enable;
    message = ''
      systemd-networkd must be enabled (systemd.network.enable) because we will configure
      dhcpcd to only send the DUID but don't assign an address.
    '';
  } ];

  # We must authenticate ourselves by sending the correct DUID in order to use our IPv6 prefix:
  # https://www.scaleway.com/en/docs/dedibox-network/ipv6/quickstart/
  # -> not supported anymore for NixOS because it is end-of-life
  # https://www.scaleway.com/en/docs/tutorials/dhcpcd-dedibox/
  networking.dhcpcd = {
    enable = true;
    allowInterfaces = [ "enp1s0f0" ];
    # don't *ever* deconfigure the IP - not useful for a static IP and would be very disruptive
    persistent = true;
    # dhcpcd won't configure any IP of its own and it will ignore the one from networkd
    # so this would wait forever.
    wait = "background";

    extraConfig = ''
      # Send our DUID - the main and only purpose of this.
      duid

      # don't touch resolv.conf and hostname, please
      # (might be redundant with `noconfigure` but let's keep it, for now)
      nohook resolv.conf  # -> should use resolveconf but that doesn't seem to work
      nohook hostname

      # We are only doing this to send the DUID so skip IPv4 and don't configure anything.
      # systemd-networkd will set the IPs.
      #ipv6only  # -> DUID is sent with DHCP for IPv4 so actually keep that enabled.
      noconfigure

      option rapid_commit
      option domain_name_servers, domain_name, domain_search, host_name
      option classless_static_routes
      option interface_mtu
      require dhcp_server_identifier
      
      slaac hwaddr
      inform6
      
      debug
    '';
  };
  
  systemd.services.dhcpcd = {
    preStart = ''
      # Copy our DUID to /var/db so dhcpcd will use it instead of generating one.
      [ -e /var/db ] || install -o root -g root -m 0755 -d /var/db
      install -o root -g root -m 0750 -d /var/db/dhcpcd
      install -m 0400 /etc/nixos/secret/by-host/sonline0-initrd/duid /var/db/dhcpcd/duid
    '';
  };
}
