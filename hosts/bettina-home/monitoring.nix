{ lib, pkgs, config, privateForHost, ... }:
let
  muninSshConfig = pkgs.writeText "munin-ssh-config" ''
    # Default values of `ssh_options` in Munin
    # (This disables host key checking which isn't great but should be ok in our case.)
    ChallengeResponseAuthentication no
    #StrictHostKeyChecking no
    StrictHostKeyChecking accept-new

    Host ha
      User root
      HostName ${privateForHost.homeassistantIP}
      # The real system, not the SSH addon.
      #NOTE This has to be repeated in the Munin config because Munin will pass `-o Port=...` to SSH,
      #     which superseedes our setting here.
      Port 22222
      #IdentityFile $CREDENTIALS_DIRECTORY/munin-ssh-key
      IdentityFile /run/credentials/munin-cron.service/munin-ssh-key
  '';

  # error output of SSH seems to go nowhere so we redirect it to a log file
  sshWithLog = pkgs.writeShellScript "munin-ssh" ''
    exec 2>>/var/log/munin/ssh.txt
    set -x
    date >&2
    #echo CREDENTIALS_DIRECTORY=$CREDENTIALS_DIRECTORY
    #ls -l $CREDENTIALS_DIRECTORY >&2
    exec ${pkgs.openssh}/bin/ssh "$@"
  '';

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

  munin-cgi-html = pkgs.writeShellScriptBin "munin-cgi-html" ''
    export MUNIN_CONFIG=${muninConfig}
    exec ${pkgs.perl}/bin/perl -T ${cgiPathArgs} ${pkgs.munin}/www/cgi/.munin-cgi-html-wrapped
  '';

  munin-cgi-graph = pkgs.writeShellScriptBin "munin-cgi-graph" ''
    export MUNIN_CONFIG=${muninConfig}
    exec ${pkgs.perl}/bin/perl -T ${cgiPathArgs} ${pkgs.munin}/www/cgi/.munin-cgi-graph-wrapped
  '';
in
{
  services.munin-cron = {
    enable = true;

    extraGlobalConfig = ''
      #ssh_command "${pkgs.openssh}/bin/ssh"
      ssh_command "${sshWithLog}"
      ssh_options -F ${muninSshConfig}

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

      [homeassistant]
      # see notes.txt w.r.t. configuration in the VM
      address ssh://ha:22222/mnt/overlay/muninlite
    '';
  };
  services.munin-node.enable = true;

  systemd.services.munin-cron = {
    serviceConfig.SetCredential = [ "munin-ssh-key:-" ];  # fallback value
    serviceConfig.LoadCredential = [
      "munin-ssh-key:/etc/nixos/secret/by-host/bettina-home/munin-ssh-key"
    ];

    path = [ pkgs.openssh pkgs.util-linux ];
  };

  services.logrotate = {
    enable = true;
    settings.munin = {
      files = [
        "/var/log/munin/ssh.txt"
        "/var/log/munin/.munin-*.log"
      ];
      frequency = "daily";
      minsize = "1M";
      rotate = 10;
      delaycompress = true;
    };
  };

  #FIXME remove later
  environment.systemPackages = [ munin-cgi-html munin-cgi-graph ];

  # see https://github.com/munin-monitoring/munin/blob/stable-2.0/doc/example/webserver/nginx.rst
  systemd.services.munin-cgi-graph = {
    wantedBy = [ "multi-user.target" ];

    environment.MUNIN_CONFIG = muninConfig;

    serviceConfig = {
      #FIXME use systemd socket to create the socket
      #User = "munin";
      ExecStart = "${pkgs.spawn_fcgi}/bin/spawn-fcgi -n -s /var/run/munin/fastcgi-graph.sock -U nginx -u munin -g munin -- "
        + "${pkgs.perl}/bin/perl -T ${cgiPathArgs} ${pkgs.munin}/www/cgi/.munin-cgi-graph-wrapped";
      RuntimeDirectory = "munin-cgi-tmp";
    };
  };
  systemd.services.munin-cgi-html = {
    wantedBy = [ "multi-user.target" ];

    environment.MUNIN_CONFIG = muninConfig;

    serviceConfig = {
      #FIXME use systemd socket to create the socket
      #User = "munin";
      ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 700 /run/munin-cgi-tmp/munin-cgi-graph";
      ExecStart = "${pkgs.spawn_fcgi}/bin/spawn-fcgi -n -s /var/run/munin/fastcgi-html.sock -U nginx -u munin -g munin -- "
        + "${pkgs.perl}/bin/perl -T ${cgiPathArgs} ${pkgs.munin}/www/cgi/.munin-cgi-html-wrapped";
      RuntimeDirectory = "munin-cgi-tmp";
    };
  };
}
