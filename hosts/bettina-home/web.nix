{ pkgs, privateForHost, secretForHost, ... }:
let
  inherit (privateForHost) domain;
  #FIXME remove the "4" (as soon as TTLs have passed)
  domain1 = "bettina-home4.${domain}";
  domain2 = "bettina-home4-local.${domain}";
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
      addSSL = true;
      #forceSSL = true;

      locations."/index.html".extraConfig = ''
        # only cache for a short time and only in memory
        # so we don't need manual updates and we notice
        # when network is down
        expires 60s;
        add_header Cache-Control "no-cache";
      '';
    };
    virtualHosts."wlan.${domain1}" = {
      useACMEHost = domain1;
      addSSL = true;
      locations."/".proxyPass = "http://localhost:8088/";
    };
    virtualHosts."zigbee.${domain1}" = {
      useACMEHost = domain1;
      addSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:8086/";
        proxyWebsockets = true;
      };
    };
    virtualHosts."ha.${domain1}" = {
      useACMEHost = domain1;
      addSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:8123/";
        proxyWebsockets = true;
      };
    };
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
      # &>/var/lib/acme/bettina-home.bkoch.info/debug.log
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
      domain2
      "*.${domain1}"
      "*.${domain2}"
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
