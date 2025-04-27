{ lib, pkgs, config, domain, smtpHost, ports, ... }:
let
  hostName = "discuss.${domain}";
  port = ports.omas-discourse.port;
in
{
  services.nginx.virtualHosts.${hostName} = {
    listen = [
      { addr = "0.0.0.0"; inherit port; }
    ];
    locations."= /favicon.ico".alias = "/var/www/html-intern/ogr-favicon-d.ico";
  };

  services.discourse = {
    enable = true;
    nginx.enable = true;
    enableACME = false;

    hostname = hostName;

    admin = {
      passwordFile = "/run/credentials/discourse.service/secret_discourse-admin-password";
      fullName = "root";
      username = "root";
      email = "postmaster@${domain}";
    };

    database.createLocally = true;
    database.host = null;  # use Unix socket
    # version check seems to be about too old version but ours is "too new"
    database.ignorePostgresqlVersion = true;

    # generate with: openssl rand -hex 64
    secretKeyBaseFile = "/run/credentials/discourse.service/secret_discourse-secret-key-base";

    # see https://github.com/discourse/discourse/blob/main/config/site_settings.yml
    siteSettings = {
      required = {
        title = "Omadiskussion";
        site_description = "";
        #notification_email = "noreply@${domain}";
        notification_email = "discuss@${domain}";
      };
    };

    mail.notificationEmailAddress = "discuss@${domain}";
    mail.outgoing = {
      username = "discuss@${domain}";
      serverAddress = smtpHost;
      port = 465;
      passwordFile = "/run/credentials/discourse.service/secret_discourse-smtp-password";
      forceTLS = true;
      domain = domain;
      authentication = "login";
    };

    redis.passwordFile = "/run/credentials/discourse.service/secret_discourse-redis-password";
  };

  services.redis.servers.discourse.requirePassFile = "/run/credentials/redis-discourse.service/secret_discourse-redis-password";

  systemd.services.discourse.serviceConfig.LoadCredential = [
    "secret_discourse-admin-password"
    "secret_discourse-secret-key-base"
    "secret_discourse-smtp-password"
    "secret_discourse-redis-password"
  ];
  systemd.services.redis-discourse.serviceConfig.LoadCredential = [
    "secret_discourse-redis-password"
  ];
}
