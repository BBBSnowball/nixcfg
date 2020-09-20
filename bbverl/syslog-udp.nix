{ config, pkgs, ... }:
let
  config = pkgs.writeText "rsyslog.udp.conf" ''
    $ModLoad imudp
    $UDPServerRun 514

    #ruleset(name="remoterules"){
    #  action(type="omfile" file="/var/log/remote-$fromhost-ip")
    #  stop
    #}
    #input(type="impudp" port="514" ruleset="remoterules");

    # see http://www.rsyslog.com/doc/v8-stable/configuration/templates.html
    #$template FileFormat,"%TIMESTAMP:::date-rfc3339% %HOSTNAME% %syslogtag%%msg:::sp-if-no-1st-sp%%msg:::drop-last-lf%\n"
    $template WithLocalTime,"%timegenerated:::date-rfc3339% %TIMESTAMP:::date-rfc3339% %HOSTNAME% %STRUCTURED-DATA% %syslogtag% %syslogseverity-text:::uppercase% %msg:::escape-cc%\n"

    $template REMOTEFILENAME,"/var/log/host-%fromhost%/syslog.log"
    #:FROMHOST, !isequal, "beaglebone" ?REMOTEFILENAME
    *.* ?REMOTEFILENAME;WithLocalTime

    # This is similar to the default config.
    #$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
    #$ActionFileDefaultTemplate WithLocalTime
    $FileOwner root
    $FileGroup adm
    $FileCreateMode 0640
    $DirCreateMode 0755
    $Umask 0022
    $WorkDirectory /var/spool/rsyslog-udp
  '';
in
{
  environment.systemPackages = [ pkgs.rsyslog ];

  #FIXME I would really like to run this as non-root. However, it seems that socket
  #      activation is only possible for imuxsock and it explicitely checks that the
  #      fd is a Unix socket. We need imudp on a priviledged port so we are out of
  #      luck. Furthermore, I couldn't find any option for dropping priviledges.
  #      I think, I should disable this while not in use and switch to a different
  #      syslog daemon in the long run.
  systemd.services.rsyslog-udp = {
    description = "System Logging Service for remote hosts";
    documentation = [
      "man:rsyslogd(8)"
      "http://www.rsyslog.com/doc/"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "notify";
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /var/spool/rsyslog-udp"
        "${pkgs.coreutils}/bin/chmod 700 /var/spool/rsyslog-udp"
      ];
      ExecStart = "${pkgs.rsyslog}/sbin/rsyslogd -n -f ${config} -i /var/run/rsyslogd-udp.pid";
      Restart = "on-failure";
      # don't send output to journal
      #StandardOutput = "null";
    };
  };

  #FIXME only in local network
  networking.firewall.interfaces.br0.allowedUDPPorts = [ 514 ];

  services.shorewall.rules.syslog = {
    proto = "udp";
    destPort = [ 514 ];
  };
}
