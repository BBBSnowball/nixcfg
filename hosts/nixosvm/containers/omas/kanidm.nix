{ lib, pkgs, domain, ports, ... }:
let
  hostName = "accounts.${domain}";
  port = ports.omas-accounts.port;
in
{
  services.kanidm = {
    enableServer = true;
    enableClient = true;

    # run *before* changing this:
    #   kanidmd domain upgrade-check
    # see https://kanidm.github.io/kanidm/stable/server_updates.html
    package = pkgs.kanidm_1_5.withSecretProvisioning;

    clientSettings = {
      uri = "https://127.0.0.1:${toString port}";
      ca_path = "/run/credentials/kanidm.service/secret_kanidm-cert.pem";
    };

    serverSettings = {
      # Generate with:
      # openssl req -x509 -newkey rsa:4096 -keyout kanidm-key.pem -out kanidm-cert.pem -sha256 -days 36500 -nodes -subj "/CN=<ip>:<port>"
      tls_key = "/run/credentials/kanidm.service/secret_kanidm-key.pem";
      tls_chain = "/run/credentials/kanidm.service/secret_kanidm-cert.pem";

      # see https://kanidm.github.io/kanidm/stable/domain_rename.html
      domain = hostName;
      origin = "https://${hostName}";

      bindaddress = "0.0.0.0:${toString port}";
      ldapbindaddress = "127.0.0.1:3890";
    };

    provision = {
      enable = true;

      # Generate with:
      #   LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32 >kanidm-admin-password
      adminPasswordFile = "/run/credentials/kanidm.service/secret_kanidm-admin-password";
      idmAdminPasswordFile = "/run/credentials/kanidm.service/secret_kanidm-admin-password";
    
      groups.test.present = true;
      persons.a = {
        displayName = "a";
      };
    };
  };

  systemd.services.kanidm = {
    serviceConfig.LoadCredential = [ "secret_kanidm-key.pem" "secret_kanidm-cert.pem" "secret_kanidm-admin-password" ];
    after = [ "postgresql.service" ];
  };
} 
