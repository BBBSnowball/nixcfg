{ lib, pkgs, privateForHost, secretForHost, ... }:
{
  programs.msmtp = {
    enable = true;
    setSendmail = true;

    # see https://wiki.archlinux.org/title/msmtp
    extraConfig = let p = privateForHost.mail; in 
    ''
      defaults
      auth           on
      tls            on
      tls_trust_file /etc/ssl/certs/ca-certificates.crt
      logfile        ~/.msmtp.log

      # Gmail
      account        mail
      host           ${p.smtpHost}
      port           ${toString p.smtpPort}
      tls_starttls   off
      from           ${p.from}
      user           ${p.username}
      #FIXME This fails because msmtp uses popen, which goes through /bin/sh and kills the setuid rights.
      passwordeval   ${pkgs.coreutils}/bin/cat /etc/msmtp-password

      # Set a default account
      account default: mail
    '';
  };

  # default is to set this to root and don't setuid but we need setuid to access the password
  services.mail.sendmailSetuidWrapper = lib.mkIf {
    setuid = lib.mkForce true;
    setgid = lib.mkForce true;
    owner = lib.mkForce "msmtp";
    group = lib.mkForce "msmtp";
  };

  users.users.msmtp = {
    isSystemUser = true;
    group = "msmtp";
  };
  users.groups.msmtp = {};

  systemd.services.msmtp-password = {
    wantedBy = [ "network.target" "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    serviceConfig.ExecStart = "${pkgs.coreutils}/bin/install -C -m 0400 -o msmtp -g msmtp "
      + "${secretForHost}/msmtp-password /etc/msmtp-password";
  };
}