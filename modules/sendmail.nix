{ lib, pkgs, config, ... }:
let
  cfg = config.programs.sendmail-to-smarthost;
  socket = "/run/msmtp/socket";
in
{
  options = with lib; {
    programs.sendmail-to-smarthost = {
      enable = mkEnableOption "msmtp for forwarding emails to smarthost";
      enablePort25 = mkEnableOption "submission of emails via local port 25";
      enableNotifyService = mkEnableOption "notify-by-mail service (for use in `unitConfig.OnFailure`)";

      smtpHost = mkOption {
        type = types.str;
        description = "SMTP smarthost";
      };

      smtpHostReal = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Real name of SMTP smarthost, i.e. name in the TLS certificate";
      };

      smtpPort = mkOption {
        type = types.port;
        default = 587;
        description = "Port for mail submission on smarthost";
      };
    
      #NOTE You can set `from` to username+%U@domain to include the name of the user that is calling sendmail
      #     but keep in mind that this can be faked by setting $USER or $LOGNAME.
      sender = mkOption {
        type = types.str;
        example = "noreply@example.com";
        description = "Address for sending mail from (and also default username for smarthost)";
      };

      username = mkOption {
        type = types.str;
        example = "noreply@example.com";
        description = "Username for smarthost";
      };

      passwordFile = mkOption {
        type = types.str;
        example = lib.literalExpression "\"\${secretForHost}/msmtp-password\"";
        description = "File with password for smarthost (readable by root), can be a credential name instead of a file";
      };

      adminEmail = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "yourself@example.com";
        description = "The service notify-by-mail will send email to this address";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.sendmail-to-smarthost = {
      username = lib.mkDefault cfg.sender;
      enableNotifyService = lib.mkDefault (cfg.adminEmail != null);
    };

    assertions = [
      {
        assertion = !cfg.enableNotifyService || cfg.adminEmail != null;
        message = "adminEmail is required if enableNotifyService is true";
      }
    ];

    # see https://wiki.archlinux.org/title/msmtp
    programs.msmtp = {
      enable = true;
      setSendmail = true;
  
      defaults = {
        from = cfg.sender;  # sendmail.nix: p.from, only set for the local account
        syslog = true;
        tls_trust_file = "/etc/ssl/certs/ca-certificates.crt";
      };

      # We won't be able to read the password as the sending user and setuid is unwanted
      # and unreliable in services (e.g. PrivateDevices=true breaks it). Therefore, we
      # pass the mail to our local msmtpd, which will forward it to the smarthost.
      accounts.default = {  # sendmail.nix was calling it "local" and used port 25
        inherit socket;
        set_from_header = true;
        auth = false;
        tls = false;
        #tls_starttls = false;  # ?

        # This causes error "envelope-from address is missing" although it should
        # use the value of the `from` setting - at least that's how I understand
        # the documentation. Anyway, the smarthost will check it so we don't have
        # to be too strict here.
        #allow_from_override = false;
      };

      accounts.local = lib.mkIf cfg.enablePort25 {
        host = "localhost";
        port = "25";

        # like accounts.default
        set_from_header = true;
        auth = false;
        tls = false;
        #tls_starttls = false;
        #allow_from_override = false;
      };
      
      accounts.smarthost = {
        auth = true;
        host = cfg.smtpHost;
        #tls_host_override = lib.mkIf (cfg.smtpHostReal != null) cfg.smtpHostReal;
        port = toString cfg.smtpPort;
        user = cfg.username;  # was sender / username
        passwordeval = "cat $CREDENTIALS_DIRECTORY/password";
        tls = true;
        #tls_starttls = false;
      } // (if cfg.smtpHostReal != null then {
        tls_host_override = cfg.smtpHostReal;
      } else {});
    };
  
    systemd.sockets.msmtp = {
      description = "MSMTP daemon forwards mail to smarthost";
      wantedBy = [ "sockets.target" ];
      listenStreams = [ socket ];
      socketConfig.Accept = true;  # inetd mode
    };

    systemd.sockets.msmtp25 = lib.mkIf cfg.enablePort25 {
      description = "MSMTP daemon forwards mail to smarthost";
      wantedBy = [ "sockets.target" ];
      listenStreams = [ "127.0.0.1:25" ];
      socketConfig.Accept = true;  # inetd mode
    };
  
    systemd.services = let
      forwarding_service = {
        description = "MSMTP daemon (inetd)";
    
        serviceConfig = {
          # We tried to point it to a different config with $HOME and $SYSCFGDIR but that didn't work
          # so we are left with the somewhat ugly `--command=...`.
          # The "-" prefix is to ignore any errors because client errors are likely to cause an error exit value.
          ExecStart = "-${pkgs.msmtp}/bin/msmtpd --inetd --log=syslog --command=\"${pkgs.msmtp}/bin/msmtp -f %%F --account=smarthost --\"";
    
          StandardInput = "socket";
          StandardError = "journal";
    
          LoadCredential = [ "password:${cfg.passwordFile}" ];
    
          User = "msmtp";
          DynamicUser = true;
        };
      };
    in {
      "msmtp@" = forwarding_service;
      "msmtp25@" = lib.mkIf cfg.enablePort25 forwarding_service;

      "notify-by-mail@" = let
        # $text can contain UTF-8, so let's encode it and specify the charset.
        # (Thunderbird will do the right thing anyway but K8 won't.)
        # Without MIME encoding this could be as simple as:
        #   echo "Subject: [$1] service $2 failed"
        #   echo ""
        #   systemctl status --full -n30 "$2"
        script = pkgs.writeShellScript "notify-by-mail" ''
          (
            boundary="===============x$(pwgen -s 20 1)=="
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
          ) | sendmail "$ADMIN_EMAIL"
        '';
      in lib.mkIf cfg.enableNotifyService {
        description = "send an email when a service fails";

        path = with pkgs; [
          pwgen
          systemd

          # use sendmail directly from msmtp package
          # because we don't need a suid wrapper
          # (which would be at /run/wrappers/bin/sendmail)
          config.programs.msmtp.package
        ];

        environment.ADMIN_EMAIL = cfg.adminEmail;

        serviceConfig.Type = "oneshot";
        serviceConfig.ExecStart = "${script} %H %i";
      };
    };
  };
}
