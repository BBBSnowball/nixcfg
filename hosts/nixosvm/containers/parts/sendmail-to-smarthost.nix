{ lib, pkgs, config, ... }:
#FIXME merge this with our sendmail module (This one is better because it uses a Unix socket.)
let
  cfg = config.programs.sendmail-to-smarthost;
  socket = "/run/msmtp/socket";
in
{
  options = with lib; {
    programs.sendmail-to-smarthost = {
      enable = mkEnableOption "Enable msmtp for forwarding emails to smarthost";

      smtpHost = mkOption {
        type = types.str;
        description = "SMTP smarthost";
      };

      smtpHostReal = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Real name of SMTP smarthost, i.e. name in the TLS certificate";
      };
    
      #NOTE You can set `from` to username+%U@domain to include the name of the user that is calling sendmail
      #     but keep in mind that this can be faked by setting $USER or $LOGNAME.
      sender = mkOption {
        type = types.str;
        example = "noreply@example.com";
        description = "Address for sending mail from (and also username for smarthost)";
      };

      passwordFile = mkOption {
        type = types.str;
        description = "File with password for smarthost (readable by root)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.msmtp = {
      enable = true;
      setSendmail = true;
  
      defaults = {
        from = cfg.sender;
        syslog = true;
        tls_trust_file = "/etc/ssl/certs/ca-certificates.crt";
      };

      # We won't be able to read the password as the sending user and setuid is unwanted
      # and unreliable in services (e.g. PrivateDevices=true breaks it). Therefore, we
      # pass the mail to our local msmtpd, which will forward it to the smarthost.
      accounts.default = {
        inherit socket;
        set_from_header = true;
        auth = false;
        tls = false;
      };
      
      accounts.smarthost = {
        auth = true;
        host = cfg.smtpHost;
        #tls_host_override = lib.mkIf (cfg.smtpHostReal != null) cfg.smtpHostReal;
        port = "587";
        user = cfg.sender;
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
  
    systemd.services."msmtp@" = {
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
  };
}
