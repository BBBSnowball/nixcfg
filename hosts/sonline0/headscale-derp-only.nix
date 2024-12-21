{ lib, pkgs, privateForHost, secretForHost, ... }:
let
  # 3478 is already used by coturn.
  stunport = 3480;
  derpport = 1443;

  domain = "derp2.${privateForHost.infoDomain}";

  # We have TLS offloading in a VM, so don't enable it here.
  # (This will disable gRPC because we won't have any TLS for that
  #  but we don't need it anyway.)
  useTls = true;
in
{
  #NOTE This doesn't work, yet. The DERP server doesn't seem to be started.
  services.headscale = {
    enable = true;
    settings = {
      server_url = "https://${domain}";
      #listen_addr = "${privateForHost.net.internalPrefix}.129:8080";
      #listen_addr = "${privateForHost.net.ip0}:${toString derpport}";
      listen_addr = ":${toString derpport}";
      metrics_listen_addr = "127.0.0.1:9090";
      grpc_listen_addr = "127.0.0.1:50443";

      #NOTE These are not necessary. We thought that they might be needed for DERP
      #     but that was disabled due to a typo in the config.
      tls_cert_path = lib.mkIf useTls "/var/lib/acme/${domain}/fullchain.pem";
      tls_key_path = lib.mkIf useTls "/var/lib/acme/${domain}/key.pem";

      derp.server = {
        #NOTE `enabled`, not `enable` !
        enabled = true;
        region_id = 900;
        
        region_code = "sonline0";
        region_name = "sonline0";
        stun_listen_addr = ":${toString stunport}";
        #stun_listen_addr = "${privateForHost.net.ip0}:${toString stunport}";
        #private_key_path = "/var/lib/headscale/derp_server_private.key";
        ipv4 = privateForHost.net.ip0;
        ipv6 = privateForHost.net.ipv6;
      };
      derp.urls = [];
      derp.paths = [ "/etc/headscale/derp.yaml" ];

      # just to avoid the warning
      ip_prefixes = [ "100.64.0.0/10" ];
    };
  };

  # The service will often close its database and then hang until it is killed.
  # There is no point in waiting for that for too long.
  systemd.services.headscale.serviceConfig.TimeoutStopSec = 5;
  systemd.services.headscale.after = lib.mkIf useTls [
    # Wait for file to exist (selfsigned) or acme to be done?
    # -> No reason to start before acme is done, I think.
    "acme-${domain}.service"
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
            hostname: ${domain}
            ipv4: ${privateForHost.net.ip0}
            ipv6: "${privateForHost.net.ipv6}"
            stunport: ${toString stunport}
            stunonly: false
            derpport: ${toString derpport}
  '';

  #NOTE This needs additional config on mailinabox.
  #  see ../bettina-home/web-acme/README.md
  #  - `_acme-challenge.${domain}`: `CNAME something.domain-without-dnssec.`
  #  - add something.domain-without-dnssec to /etc/nsd/nsd.conf.d/zones2.conf
  #  - SSH forced-command for our SSH key

  security.acme.acceptTerms = true;
  security.acme.certs."${domain}" =
  let
    dnsScript = pkgs.writeShellScript "acme-dns-mailinabox" ''
      # default shell is nologin, which will break ssh
      export SHELL=${pkgs.bash}/bin/bash
      cd $CREDENTIALS_DIRECTORY
      exec ${pkgs.openssh}/bin/ssh -F $PWD/ssh_config -o BatchMode=yes target -- "$@"
      # &>/var/lib/acme/${domain}/debug.log
    '';
    environmentFile = pkgs.writeText "acme.env" ''
      EXEC_MODE=
      EXEC_PATH=${dnsScript}
      # default values
      #EXEC_POLLING_INTERVAL=2
      #EXEC_PROPAGATION_TIMEOUT=60
      #EXEC_SEQUENCE_INTERVAL=60
    '';
  in
  lib.mkIf useTls {
    email = privateForHost.acmeEmail;
    dnsProvider = "exec";
    extraDomainNames = [
    ];
    inherit environmentFile;
    dnsResolver = "1.1.1.1:53";
    dnsPropagationCheck = false;  # disable check of all primary servers
    group = "headscale";
    reloadServices = "headscale.service";
  };

  systemd.services."acme-${domain}".serviceConfig.LoadCredential = [
    "ssh:${secretForHost}/acme-dns-update-ssh"
  ];
}
