{ privateForHost, ... }:
let
  # 3478 is already used by coturn.
  stunport = 3480;
in
{
  #NOTE This doesn't work, yet. The DERP server doesn't seem to be started.
  services.headscale = {
    enable = true;
    settings = {
      server_url = "https://derp1.${privateForHost.infoDomain}";
      #tls_cert_path = "";
      #tls_key_path = "";
      listen_addr = "${privateForHost.net.internalPrefix}.129:8080";
      metrics_listen_addr = "127.0.0.1:9090";

      derp.server = {
        enable = true;
        region_id = 900;
        
        region_code = "headscale";
        region_name = "Headscale Embedded DERP";
        #stun_listen_addr = ":3480";
        stun_listen_addr = "${privateForHost.net.ip0}:${toString stunport}";
        #private_key_path = "/var/lib/headscale/derp_server_private.key";
        ipv4 = privateForHost.net.ip0;
        ipv6 = privateForHost.net.ipv6;
      };
      derp.urls = [];

      # just to avoid the warning
      ip_prefixes = [ "100.64.0.0/10" ];
    };
  };

  # The service will often close its database and then hang until it is killed.
  # There is no point in waiting for that for too long.
  systemd.services.headscale.serviceConfig.TimeoutStopSec = 5;
}
