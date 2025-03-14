{ config, lib, modules, pkgs, privateForHost, secretForHost, nixpkgs-24-05, ... }:
let
  inherit (pkgs) system;
  ports = config.networking.firewall.allowedPorts;
  name = "c";
  containerName = name;
  hostNameMain = name;
  hostName1 = "c1";

  creds = "/run/credentials/nginx.service";
  makeSslVHost = name: {
    listen = [
      #{ addr = "0.0.0.0"; port = ports.c1.port; ssl = true; }
      { addr = "[::]";    port = ports.${name}.port; ssl = true; }
    ];
    #adminAddr = "postmaster@localhost";
    serverAliases = [ name ];
    root = "/var/www/html";

    onlySSL = true;
    sslCertificate = "${creds}/secret_clown-${name}-cert.pem";
    sslCertificateKey = "${creds}/secret_clown-${name}-key.pem";
    # Check with: openssl s_client -connect localhost:8099 -showcerts |& openssl x509 -text | grep DNS
  };
in {
  containers.${name} = {
    autoStart = true;
    config = { config, pkgs, ... }: {
      imports = [
        modules.container-common
        "${privateForHost}/module-c"
      ];

      _module.args = { inherit nixpkgs-24-05; };

      services.nginx.enable = true;

      services.nginx.virtualHosts = {
        # redirect HTTP to HTTPS, similar to forceSSL but custom port
        http = {
          listen = [
            #{ addr = "0.0.0.0"; port = ports.c-http.port; }
            { addr = "[::]";    port = ports.c-http.port; }
          ];
  
          locations."/" = {
            extraConfig = ''
              return 301 https://$host$request_uri;
            '';
          };
        };

        c1 = makeSslVHost "c1";
        c2 = makeSslVHost "c2";
        c3 = makeSslVHost "c3";
        c4 = makeSslVHost "c4";
      };

      systemd.services."nginx" = {
        serviceConfig.LoadCredential = [
          "secret_clown-c1-key.pem" "secret_clown-c1-cert.pem"
          "secret_clown-c2-key.pem" "secret_clown-c2-cert.pem"
          "secret_clown-c3-key.pem" "secret_clown-c3-cert.pem"
          "secret_clown-c4-key.pem" "secret_clown-c4-cert.pem"
        ];
      };
    };

    # This doesn't support directories, it seems.
    #extraFlags = [ "--load-credential=secret:${secretForHost}/${name}/" ];
    # Bind-mount the credentials to one of the paths where systemd will look by default.
    bindMounts."/run/credstore".hostPath = "/run/credentials/container@${containerName}.service";
  };

  systemd.services."container@${containerName}".serviceConfig.LoadCredential = [ "secret:${secretForHost}/${name}/" ];

  networking.firewall.allowedPorts.c-http = 8095;
  networking.firewall.allowedPorts.c1 = 8096;
  networking.firewall.allowedPorts.c2 = 8097;
  networking.firewall.allowedPorts.c3 = 8098;
  networking.firewall.allowedPorts.c4 = 8099;
}
