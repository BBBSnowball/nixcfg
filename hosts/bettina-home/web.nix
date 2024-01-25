{ pkgs, privateForHost, secretForHost, ... }:
let
  inherit (privateForHost) domain;
  domain1 = "bettina-home.${domain}";

  simpleProxyPass = target: {
    useACMEHost = domain1;
    #addSSL = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = target;
      proxyWebsockets = true;
    };
  };
in
{
  services.nginx = {
    enable = true;
    virtualHosts."default" = {
      #root = "/var/www/default";
      root = ./html;

      locations."/index.html".extraConfig = ''
        # only cache for a short time and only in memory
        # so we don't need manual updates and we notice
        # when network is down
        expires 60s;
        add_header Cache-Control "no-cache";
      '';
    };
    virtualHosts."${domain1}" = {
      root = ./html;
      useACMEHost = domain1;
      #addSSL = true;   # provide HTTPS and let the user choose
      forceSSL = true;  # redirect to HTTPS if user tries to use HTTP

      locations."/index.html".extraConfig = ''
        # only cache for a short time and only in memory
        # so we don't need manual updates and we notice
        # when network is down
        expires 60s;
        add_header Cache-Control "no-cache";
      '';
    };
    virtualHosts."wlan.${domain1}" = simpleProxyPass "http://localhost:8088/";
    virtualHosts."zigbee.${domain1}" = simpleProxyPass "http://localhost:8086/";
    virtualHosts."ha.${domain1}" = simpleProxyPass "http://localhost:8123/";
    virtualHosts."passwords.${domain1}" = simpleProxyPass "http://localhost:8000/";
    virtualHosts."speedport.${domain1}" = simpleProxyPass "http://192.168.2.1:80/";
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
