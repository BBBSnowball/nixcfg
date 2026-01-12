{ config, lib, pkgs, ports, domain, reverse_proxy_ip, createDatabase, ... }:
{
  config = {
    services.mastodon = {
      enable = true;
      localDomain = domain;  # domain for usernames
      extraConfig.WEB_DOMAIN = "mastodon.${domain}";  # domain for web pages
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

      streamingProcesses = 3;
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
      #elasticsearch.port = 9200;

      enableUnixSocket = true;
      redis.enableUnixSocket = true;
      database.host = "/run/postgresql";

      mediaAutoRemove.startAt = "1:00";  # daily but with an offset

      extraEnvFiles = [];

      #elasticsearch.prefix
      #elasticsearch.user
      #elasticsearch.preset
      #elasticsearch.port
      #elasticsearch.passwordFile
      #elasticsearch.host

      # see https://docs.joinmastodon.org/admin/troubleshooting/
      # and https://docs.joinmastodon.org/admin/config/#rails_log_level
      extraConfig.RAILS_LOG_LEVEL = "warn"; # or "info" or "debug"
      extraConfig.LOG_LEVEL = "info";  # or "silly"
    };

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
    };
    #services.nginx.recommendedProxySettings = lib.mkForce false;

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
