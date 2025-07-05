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
    locations."@discourse".recommendedProxySettings = false;
    locations."@discourse".extraConfig = ''
      proxy_set_header        Host "${hostName}";
      proxy_set_header        X-Real-IP $remote_addr;
      proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header        X-Forwarded-Proto https;
      proxy_set_header        X-Forwarded-Host "${hostName}";
      proxy_set_header        X-Forwarded-Server "${hostName}";
    '';
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
    # and https://github.com/discourse/discourse/blob/main/config/discourse_defaults.conf
    siteSettings = {
      required = {
        title = "Omadiskussion";
        site_description = "";
        #notification_email = "noreply@${domain}";
        notification_email = "discuss@${domain}";
        force_https = true;
      };

      # We are not using NixOS' mail.incoming because that would use Postfix.
      # There doesn't seem to be any complete documentation on these features but see here
      # for a tutorial: https://meta.discourse.org/t/set-up-reply-by-email-with-pop3-polling/14003
      # And see here for a list of settings: /admin/site_settings/category/email
      email = {
        manual_polling_enabled = lib.mkForce true;
        reply_by_email_enabled = lib.mkForce true;
        #reply_by_email_address = "replies+%{reply_key}@${domain}";  # -> Used as sender address so must match the SMTP account.
        reply_by_email_address = "discuss+%{reply_key}@${domain}";
        log_mail_processing_failures = false;  # for debugging, see ${domain}/logs/
        # There are some settings for IMAP but not the relevant ones..? Let's stick to POP3, for now.
        pop3_polling_username = "discuss@${domain}";
        # pop3_polling_password -> set in Webinterface
        pop3_polling_host = smtpHost;
        pop3_polling_enabled = true;
        pop3_polling_ssl = true;
        pop3_polling_period_mins = 1;

        # It still leaks the unsubscribe link but that doesn't work without correct login.
        trim_incoming_emails = true;
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
    mail.incoming.replyEmailAddress = "discuss+%{reply_key}@${domain}";

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
