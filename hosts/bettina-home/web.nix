{ lib, pkgs, privateForHost, secretForHost, ... }:
let
  inherit (privateForHost) domain;
  domain1 = "bettina-home.${domain}";

  baseDomains = [
    domain1
    "vpn.${domain1}"
    "lokal.${domain1}"
  ];

  webServices = {
    wlan      = { target = "http://localhost:8088/"; };
    zigbee    = { target = "http://localhost:8086/"; };
    ha        = { target = "http://localhost:8123/"; };
    passwords = { target = "http://localhost:8000/"; };
    speedport = { target = "http://192.168.2.1:80/"; defaultUri = "6.0/gui/"; };
    switch    = { target = "http://172.18.18.4/"; };
  };

  sslSettings = {
    useACMEHost = domain1;
    #addSSL = true;   # provide HTTPS and let the user choose
    forceSSL = true;  # redirect to HTTPS if user tries to use HTTP
  };

  defaultVHost = {
    root = ./html;

    locations."/index.html".extraConfig = ''
      # only cache for a short time and only in memory
      # so we don't need manual updates and we notice
      # when network is down
      expires 60s;
      add_header Cache-Control "no-cache";
    '';
  };

  mapListToAttrs = f: xs: lib.listToAttrs (map f xs);
in
{
  services.nginx = {
    enable = true;
    virtualHosts = {
      # Client is using our IP address or some unknown host name.
      "default" = defaultVHost;
    }
    # add index page for each base domain
    // lib.flip mapListToAttrs baseDomains (name: {
      inherit name;
      value = defaultVHost // sslSettings;
    })
    # add proxy pass for each service on each base domain
    // lib.flip mapListToAttrs
    (lib.cartesianProductOfSets { baseDomain = baseDomains; service = lib.attrNames webServices; })
    ({ baseDomain, service }:
    let target = webServices.${service}.target; in
    {
      name = "${service}.${baseDomain}";
      value = sslSettings // {
        locations."/" = {
          proxyPass = target;
          proxyWebsockets = true;
        };
      };
    });
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  security.acme.acceptTerms = true;
  security.acme.certs."${domain1}" =
  let
    dnsScript = pkgs.writeShellScript "acme-dns-mailinabox" ''
      # default shell is nologin, which will break ssh
      export SHELL=${pkgs.bash}/bin/bash
      cd $CREDENTIALS_DIRECTORY
      exec ${pkgs.openssh}/bin/ssh -F $PWD/ssh_config -o BatchMode=yes target -- "$@"
      # &>/var/lib/acme/bettina-home.${domain}/debug.log
    '';
    environmentFile = pkgs.writeText "acme-bettina-home.env" ''
      EXEC_MODE=
      EXEC_PATH=${dnsScript}
      # default values
      #EXEC_POLLING_INTERVAL=2
      #EXEC_PROPAGATION_TIMEOUT=60
      #EXEC_SEQUENCE_INTERVAL=60
    '';
  in
  {
    email = privateForHost.acmeEmail;
    dnsProvider = "exec";
    extraDomainNames = [
      "*.${domain1}"
      "*.vpn.${domain1}"
      "*.lokal.${domain1}"
    ];
    inherit environmentFile;
    dnsResolver = "1.1.1.1:53";
    dnsPropagationCheck = false;  # disable check of all primary servers
    group = "nginx";
  };

  systemd.services."acme-${domain1}".serviceConfig.LoadCredential = [
    "ssh:${secretForHost}/acme-dns-update-ssh"
  ];
}
