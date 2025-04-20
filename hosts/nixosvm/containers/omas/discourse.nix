{ lib, pkgs, config, domain, ports, ... }:
let
  hostName = "discuss.${domain}";
  port = ports.omas-discuss.port;
in
{
  services.nginx.virtualHosts.${hostName} = {
    listen = [
      { addr = "0.0.0.0"; inherit port; }
    ];

    # Use explicit domain in redirect so Nginx won't include the internal port.
    locations."= /".extraConfig = lib.mkForce ''
      return 301 https://${hostName}/wiki/;
    '';
  };

  services.discourse = {
    enable = true;
    nginx.enable = true;

    admin = {
      passwordFile = "/run/credentials/discourse.service/secret_discourse-admin-password";
      fullName = "root";
      username = "root";
      email = "postmaster@${domain}";
    };

    database.createLocally = true;

    backendSettings = {
      db_socket = "TODO";
      db_host = null;
    };

    # generate with: openssl rand -hex 64
    secretKeyBaseFile = "/run/credentials/discourse.service/secret_discourse-secret-key-base";

    #FIXME outgoing email

    # see https://github.com/discourse/discourse/blob/main/config/site_settings.yml
    siteSettings = {
      required = {
        title = "Omadiskussion";
        site_description = "";
        notification_email = "noreply@${domain}";
      };
    };
  };

  systemd.services.discourse.serviceConfig.LoadCredential = [
    "secret_discourse-admin-password"
    "secret_discourse-secret-key-base"
  ];
}
