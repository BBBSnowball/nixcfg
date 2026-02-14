{ config, lib, pkgs, ports, domain, reverse_proxy_ip, createDatabase, ... }:
{
  config = {
    services.mastodon = {
      enable = true;
      localDomain = domain;  # domain for usernames
      # Let's use a subdomain for the web pages, so cookies are cleanly separated from other subdomains.
      # Mastodon gGmbH's trademark policy reminds me of the Debian Iceweasel days, so let's stay away
      # from anything related to them. Can they police our domain names? I don't think so, but let's not
      # find out.
      #extraConfig.WEB_DOMAIN = "mastodon.${domain}";
      extraConfig.WEB_DOMAIN = "troet.${domain}";  # domain for web pages
      #extraConfig.SINGLE_USER_MODE = "true";  # redirect webinterface to profile of the first user
      #trustedProxy = reverse_proxy_ip;  # default is ok, Mastodon will only see the Unix socket peer anyway

      extraConfig.DEFAULT_LOCALE = "de";
      #extraConfig.FORCE_DEFAULT_LOCALE = true;

      configureNginx = true;
      automaticMigrations = true;

      redis.createLocally = true;
      smtp.createLocally = false;
      #database.createLocally = createDatabase;
      # -> This is also needed for migrations and service dependencies and some checks will complain if we set it to false.
      database.createLocally = true;

      smtp = {
        fromAddress = "noreply@${domain}";
      };
      extraConfig.SMTP_DELIVERY_METHOD = "sendmail";

      streamingProcesses = 5;
      webProcesses = 2;
      #sidekiqProcesses = {
      #  all = {
      #    jobClasses = [ ];
      #    threads = 10;
      #  };
      #};
      sidekiqThreads = 25;

      webPort = ports.webPort.port;  # probably not used because we can use a Unix socket
      sidekiqPort = ports.sidekiqPort.port;
      elasticsearch.port = ports.elasticsearch.port;

      enableUnixSocket = true;
      redis.enableUnixSocket = true;
      database.host = "/run/postgresql";

      mediaAutoRemove.startAt = "1:00";  # daily but with an offset

      extraEnvFiles = [];

      elasticsearch.prefix = domain;
      elasticsearch.host = "localhost";  # must be set for ES_PORT to be set
      elasticsearch.user = "mastodon";
      elasticsearch.preset = "single_node_cluster";
      elasticsearch.passwordFile = "/run/credentials/mastodon-init-dirs.service/es_pass";

      # see https://docs.joinmastodon.org/admin/troubleshooting/
      # and https://docs.joinmastodon.org/admin/config/#rails_log_level
      extraConfig.RAILS_LOG_LEVEL = "warn"; # or "info" or "debug"
      extraConfig.LOG_LEVEL = "info";  # or "silly"
    };

    systemd.services.mastodon-init-dirs.serviceConfig.LoadCredential = "es_pass:secret_elasticsearch-pw-for-mastodon";

    services.nginx.virtualHosts."${domain}" = {
      forceSSL = false;
      enableACME = false;

      listen = [
        { addr = "0.0.0.0"; port = ports.mastodon.port; }
      ];

      # don't replace headers X-Forwarded-For and X-Forwarded-Proto
      locations."@proxy".recommendedProxySettings = false;
      locations."@proxy".extraConfig = ''
        proxy_set_header Host $host;
      '';
      locations."/api/v1/streaming".recommendedProxySettings = false;
      locations."/api/v1/streaming".extraConfig = ''
        proxy_set_header Host $host;
      '';

      locations."~ /impressum" = {
        alias = "/var/www/impressum.html";
        extraConfig = ''default_type text/html;'';
      };
    };
    #services.nginx.recommendedProxySettings = lib.mkForce false;

    # default is 10M, Mastodon allows up to 99M for videos
    # see https://github.com/mastodon/mastodon/blob/main/app/models/media_attachment.rb#L43
    # mailinabox uses 128M for its own endpoints and this is probably a reasonable limit for us, as well
    services.nginx.clientMaxBodySize = "128M";

    # ActionMailer is using /usr/sbin/sendmail by default and we don't have any easy way
    # to change this (because Mastodon doesn't let us set its location (in its config/email.yml).
    # Thus, we use this ugly hack.
    # (We don't link to the suid wrapper because we don't need suid here.)
    #environment.extraSetup = ''
    #  install -d $out/usr/sbin
    #  ln -sfT /run/current-system/sw/bin/sendmail $out/usr/sbin/sendmail
    #'';
    #environment.pathsToLink = [ "/usr/sbin" ];
    system.activationScripts.sendmail = {
      deps = [];
      text = ''
        install -d $out/usr/sbin
        ln -sfT /run/current-system/sw/bin/sendmail /usr/sbin/sendmail
      '';
    };
  };
}
