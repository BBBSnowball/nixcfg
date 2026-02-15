{ lib, pkgs, config, privateForHost, ... }:
let
  sendMailAlert = pkgs.writeShellScript "munin-send-mail" ''
    ( echo "Subject: $1"; echo ""; cat ) | \
    ${pkgs.msmtp}/bin/sendmail "${privateForHost.adminEmail}"
  '';


  # CGI wrapper scripts in package for Munin don't work because of taint mode:
  #  `perldoc perlrun` says: "When running taint checks, either because the program was running setuid or setgid,
  #     or the "-T" or "-t" switch was specified, neither PERL5LIB nor "PERLLIB" is consulted."
  # -> Use `-I` to add the paths to @INC and also add some more that were missing.
  cgiPath = with pkgs.perlPackages; makePerlPath [
    # copied from munin in nixpkgs
    LogLog4perl IOSocketINET6 Socket6 URI DBFile TimeDate
    HTMLTemplate FileCopyRecursive FCGI NetCIDR NetSNMP NetServer
    ListMoreUtils DBDPg LWP pkgs.rrdtool

    CGIFast CGI
    pkgs.munin
  ];
  cgiPathArgs = "-I" + lib.replaceStrings [":"] [" -I"] cgiPath;

  # ugly hack, but we also need the config file for the CGI daemons
  muninConfig = lib.lists.last (lib.splitString " " config.systemd.services.munin-cron.serviceConfig.ExecStart);

  # see https://github.com/munin-monitoring/munin/blob/stable-2.0/doc/example/webserver/nginx.rst
  # The nginx config is in web.nix.
  #
  # We are using systemd to create the FastCGI socket. We use StandardInput=socket (see first line here):
  # see https://redmine.lighttpd.net/projects/spawn-fcgi/wiki/Systemd
  cgiSocket = name: {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "/run/munin/fastcgi-${name}.sock" ];
    socketConfig.SocketUser = "nginx";
    socketConfig.SocketGroup = "nginx";
    socketConfig.SocketMode = "0600";
  };
  cgiService = name: extraConfig: extraConfig // {
    environment.MUNIN_CONFIG = muninConfig;

    serviceConfig = {
      User = "munin";
      Group = "munin";

      StandardInput = "socket";
      StandardOutput = "null";
      StandardError = "journal";

      RuntimeDirectory = "munin-cgi-tmp";

      ExecStart = "${pkgs.perl}/bin/perl -T ${cgiPathArgs} ${pkgs.munin}/www/cgi/.munin-cgi-${name}-wrapped";
    } // (extraConfig.serviceConfig or {});
  };
in
{
  services.munin-cron = {
    enable = true;

    extraGlobalConfig = ''
      cgitmpdir /run/munin-cgi-tmp

      graph_strategy cgi
      html_strategy cgi
      #html_dynamic_images 1

      contact.syslog.command logger -p user.crit -t "Munin-Alert"
      contact.email.command ${sendMailAlert} "Munin ${var:worst}: ${var:group}::${var:host}::${var:plugin}"
      #contact.email.always_send warning critical
    '';

    hosts = ''
      [${config.networking.hostName}]
      address localhost

      #df._dev_dm_0.critical = 80
      #df._dev_dm_0.warning = 70
    '';
  };

  services.munin-node = {
    enable = true;

    disabledPlugins = [
      "squeezebox_*"
    ];

    extraPlugins = {
      df_mstdn = "${pkgs.munin}/lib/plugins/df";
      #df_abs_mstdn = "${pkgs.munin}/lib/plugins/df_abs";
      df_abs_mstdn = ./munin_df_abs;
    };

    extraPluginConfig = ''
      [df]
      # df should be run as root to report all mounts, e.g. also in containers
      user root
      env.exclude_re ^/run/credentials/ ^/run/systemd/

      [df_abs]
      user root
      # This plugin is completely different from df and it doesn't support exclude_re.
      env.exclude tmpfs

      [df_mstdn]
      user root
      env.exclude_re .
      env.include_re ^/var/lib/nixos-containers/mastodon/var/lib$

      [df_abs_mstdn]
      user root
      # ugly hack: exploit improper escaping of args to supply our additional arg
      #${"env.exclude tmpfs\t/var/lib/nixos-containers/mastodon/var/lib"}
      # proper fix: patch df_abs to support extraArgs
      env.exclude tmpfs
      env.extraArgs /var/lib/nixos-containers/mastodon/var/lib
    '';

    # enable debug output for munin-node daemon
    extraConfig = lib.mkIf false ''
      log_level 4
    '';
  };

  # enable debug output for munin-node plugins
  # -> doesn't help much, at least for df_abs
  # -> use munin-run, copy plugin to temp dir and add debug prints to the plugin
  systemd.services.munin-node.environment.MUNIN_DEBUG = lib.mkIf false "1";

  systemd.services.munin-cron = {
    path = [ pkgs.openssh pkgs.util-linux ];
  };

  services.logrotate = {
    enable = true;
    settings.munin = {
      files = [
        "/var/log/munin/.munin-*.log"
      ];
      frequency = "daily";
      minsize = "1M";
      rotate = 10;
      delaycompress = true;
    };
  };

  systemd.sockets.munin-cgi-graph = cgiSocket "graph";

  systemd.services.munin-cgi-graph = cgiService "graph" {
    serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 700 /run/munin-cgi-tmp/munin-cgi-graph";
  };

  systemd.sockets.munin-cgi-html = cgiSocket "html";

  systemd.services.munin-cgi-html = cgiService "html" {};
}
