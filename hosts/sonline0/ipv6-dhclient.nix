{ lib, pkgs, config, secretForHost, nixpkgs-dhclient, ... }:
{
  assertions = [ {
    assertion = config.systemd.network.enable;
    message = ''
      systemd-networkd must be enabled (systemd.network.enable) because we will configure
      dhclient to only send the DUID but don't assign an address.
    '';
  } ];

  # We must authenticate ourselves by sending the correct DUID in order to use our IPv6 prefix:
  # https://www.scaleway.com/en/docs/dedibox-network/ipv6/quickstart/
  # -> not supported anymore for NixOS because it is end-of-life
  # https://www.scaleway.com/en/docs/tutorials/dhcpcd-dedibox/
  #
  # The above doesn't work for us so we use dhclient from an old NixOS. This is very much not ideal!
  # https://www.scaleway.com/en/docs/dedibox-network/ipv6/quickstart/
  # We replace the default script with `-sf true` because it would flush existing addresses in PREINIT6
  # and it doesn't know which addresses we want below our prefix, i.e. it wouldn't add them again.
  systemd.services.dhclient = {
    description = "Send DUID to Scaleway infrastructure to enable IPv6 routing";

    # This is only for routing of IPv6 and I really don't trust this to work so well.
    # (e.g. see here: https://lafibre.info/scaleway/stabilite-dipv6-sur-dedies-et-vm-chez-scaleway/)
    # We don't want systemd to break IPv4 things just because it can't reach its network target
    # so let's do this *after* network-online. If any application tries to use IPv6 while dhclient
    # isn't done, the replies will get lost and resend times should save us.
    after = [ "network-online.target" ];
    wants = [ "network-online.target" "network.target" ];
    serviceConfig.ExecStart = "${nixpkgs-dhclient.legacyPackages.x86_64-linux.dhcp}/bin/dhclient -cf ${secretForHost}/dhclient6.conf -6 enp1s0f0 -P -v -sf ${pkgs.coreutils}/bin/true";
  };

  networking.dhcpcd = {
    enable = false;
  };
}
