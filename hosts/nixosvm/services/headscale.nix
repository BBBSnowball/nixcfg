{ config, privateForHost, ... }:
let
  port = 8088;
  inherit (privateForHost.sonline0) infoDomain serverExternalIpv6 ipv6Net;
  inherit (config.networking) upstreamIp externalIp;
in
{
  services.headscale = {
    enable = true;
    settings = {
      server_url = "https://headscale.${infoDomain}";
      listen_addr = "${upstreamIp}:${toString port}";
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

  systemd.services.headscale.restartTriggers = [
    config.environment.etc."headscale/derp.yaml".source
  ];

  environment.etc."headscale/derp.yaml".text = ''
    OmitDefaultRegions: true
    regions:
      900:
        regionid: 900
        regioncode: sonline0
        regionname: sonline0
        nodes:
          - name: 900a
            regionid: 900
            hostname: derp2.${infoDomain}
            ipv4: ${externalIp}
            ipv6: "${serverExternalIpv6}"
            stunport: 3480
            stunonly: false
            derpport: 1443
      #901:
      #  regionid: 901
      #  regioncode: nginx
      #  regionname: nginx
      #  nodes:
      #    - name: 901b
      #      regionid: 901
      #      hostname: derp1.${infoDomain}
      #      ipv4: ${externalIp}
      #      #ipv6: "${ipv6Net.prefix}130"
      #      # coturn should work as a stun-only DERP.
      #      stunport: 3478
      #      stunonly: false
      #      # ... and port 443 will be forwarded with TLS offloading.
      #      derpport: 0
  '';
}
