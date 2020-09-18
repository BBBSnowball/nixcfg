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

  systemd.services.rsyslog-udp = {
    description = "System Logging Service for remote hosts";
    documentation = [
      "man:rsyslogd(8)"
      "http://www.rsyslog.com/doc/"
    ];
    #FIXME is this useful?
    requires = [ "syslog.socket" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      #FIXME copied from BeagleBone/Debian; can we make this a simple service?
      Type = "notify";
      #FIXME make it run as non-root, pass UDP socket from systemd if possible
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/spool/rsyslog-udp";
      ExecStartPre = "${pkgs.coreutils}/bin/chmod 700 /var/spool/rsyslog-udp";
      ExecStart = "${pkgs.rsyslog}/sbin/rsyslogd -n -f ${config} -i /var/run/rsyslogd-udp.pid";
      Restart = "on-failure";
      # don't send output to journal
      #StandardOutput = "null";
    };
  };
};
