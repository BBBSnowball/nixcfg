{ lib, pkgs, privateForHost, secretForHost, ... }:
{
  programs.msmtp = {
    enable = true;
    setSendmail = true;

    # see https://wiki.archlinux.org/title/msmtp
    extraConfig = let p = privateForHost.mail; in
    ''
      defaults
      syslog         on
      tls_trust_file /etc/ssl/certs/ca-certificates.crt

      account        local
      host           localhost
      port           25
      tls_starttls   off
      #NOTE You can set `from` to username+%U@domain to include the name of the user that is calling sendmail
      #     but keep in mind that this can be faked by setting $USER or $LOGNAME.
      from           ${p.from}
      auth           off
      tls            off
      set_from_header on

      # This causes error "envelope-from address is missing" although it should
      # use the value of the `from` setting - at least that's how I understand
      # the documentation. Anyway, the smarthost will check it so we don't have
      # to be too strict here.
      #allow_from_override off

      account        smarthost
      host           ${p.smtpHost}
      ${lib.optionalString (p ? smtpHostReal)
        "tls_host_override  ${p.smtpHostReal}"}
      port           ${toString p.smtpPort}
      tls_starttls   off
      tls            on
      auth           on
      user           ${p.username}
      passwordeval   cat $CREDENTIALS_DIRECTORY/password

      # We won't be able to read the password as the sending user and setuid is unwanted
      # and unreliable in services (e.g. PrivateDevices=true breaks it). Therefore, we
      # pass the mail to our local msmtpd, which will forward it to the smarthost.
      account default: local
    '';
  };

  systemd.sockets.msmtp = {
    description = "MSMTP daemon forwards mail to smarthost";
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:25" ];
    socketConfig.Accept = true;  # inetd mode
  };

  systemd.services."msmtp@" = {
    description = "MSMTP daemon (inetd)";

    serviceConfig = {
      # We tried to point it to a different config with $HOME and $SYSCFGDIR but that didn't work
      # so we are left with the somewhat ugly `--command=...`.
      # The "-" prefix is to ignore any errors because client errors are likely to cause an error exit value.
      ExecStart = "-${pkgs.msmtp}/bin/msmtpd --inetd --log=syslog --command=\"${pkgs.msmtp}/bin/msmtp -f %%F --account=smarthost --\"";

      StandardInput = "socket";
      StandardError = "journal";

      LoadCredential = [ "password:${secretForHost}/msmtp-password" ];

      User = "msmtp";
      DynamicUser = true;
    };
  };

  systemd.services."notify-by-mail@" = let
    # $text can contain UTF-8, so let's encode it and specify the charset.
    # (Thunderbird will do the right thing anyway but K8 won't.)
    # Without MIME encoding this could be as simple as:
    #   echo "Subject: [$1] service $2 failed"
    #   echo ""
    #   systemctl status --full -n30 "$2"
    script = pkgs.writeShellScript "notify-by-mail" ''
      (
        boundary="===============$(${pkgs.pwgen}/bin/pwgen -s 20 1)=="
        echo "Subject: [$1] service $2 failed"
        echo "Content-Type: multipart/alternative; boundary=\"$boundary\""
        echo "MIME-Version: 1.0"
        echo ""

        echo "--$boundary"
        echo "Content-Type: text/plain; charset=\"utf-8\""
        echo "MIME-Version: 1.0"
        echo "Content-Transfer-Encoding: base64"
        echo ""
        systemctl status --full -n30 "$2" \
          | base64
        echo ""
        echo "--$boundary--"
      ) | /run/wrappers/bin/sendmail ${privateForHost.mail.adminEmail}
    '';
  in {
    description = "send an email when a service fails";

    serviceConfig.Type = "oneshot";
    serviceConfig.ExecStart = "${script} %H %i";
  };
}
