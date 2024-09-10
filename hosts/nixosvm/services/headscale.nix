{ config, privateForHost, ... }:
let
  port = 8088;
in
{
  services.headscale = {
    enable = true;
    settings = {
      server_url = "https://headscale.${privateForHost.infoDomain}";
      listen_addr = "${config.networking.upstreamIp}:${toString port}";
      metrics_listen_addr = "127.0.0.1:9090";

      derp = {
        server.enable = false;
        urls = [];
        paths = [ "/etc/headscale/derp.yaml" ];
      };

      ip_prefixes = [
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
      ];

      dns_config = {
        override_local_dns = false;
      };

      logtail.enabled = false;

      # required for Fortinet
      # see https://tailscale.com/kb/1181/firewalls
      randomize_client_port = true;
    };
  };

  # The service will often close its database and then hang until it is killed.
  # There is no point in waiting for that for too long.
  systemd.services.headscale.serviceConfig.TimeoutStopSec = 5;

  networking.firewall.allowedPorts.headscale = port;

  environment.etc."headscale/derp.yaml".text = ''
    OmitDefaultRegions: true
    regions:
      900:
        regionid: 900
        regioncode: custom
        regionname: headscale
        nodes:
          - name: 900a
            regionid: 900
            hostname: derp1.${privateForHost.infoDomain}
            ipv4: ${config.networking.externalIp}
            ipv6: "${privateForHost.serverExternalIpv6}"
            # coturn should work as a stun-only DERP.
            stunport: 3478
            stunonly: true
            derpport: 0
          - name: 900b
            regionid: 900
            hostname: derp2.${privateForHost.infoDomain}
            ipv4: ${config.networking.externalIp}
            ipv6: "${privateForHost.serverExternalIpv6}"
            stunport: 3480
            stunonly: false
            derpport: 0
  '';
}