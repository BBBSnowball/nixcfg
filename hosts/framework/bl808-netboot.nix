{ ... }:
let
  ourIp = "192.168.178.29";
in
{
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    extraConfig = ''
      # inspired by https://wiki.fogproject.org/wiki/index.php?title=ProxyDHCP_with_dnsmasq
      port=0
      log-dhcp
      dhcp-no-override
      dhcp-range=${ourIp},proxy

      enable-tftp=enp0s13f0u4u4
      tftp-root=/tftpboot
      tftp-port-range=10000,10100

      # U-Boot is sending a vendor class header but with type 60 instead of 43.
      # I think, dnsmasq doesn't consider this a valid request for proxy DHCP
      # because it doesn't answer.
      dhcp-boot=default.kpxe,,${ourIp}
      dhcp-vendorclass=uboot,U-Boot
      dhcp-boot=net:uboot,bl808.kpxe,,${ourIp}

      # This is supposed to show a menu but I don't think that this will work here.
      pxe-prompt="Booting bl808 kernel", 1
      pxe-service=x86PC,"Boot bl808",bl808b.kpxe
    '';
  };

  networking.firewall.allowedUDPPorts = [ 67 69 ];
  networking.firewall.allowedUDPPortRanges = [ { from = 10000; to = 10100; } ];
}
