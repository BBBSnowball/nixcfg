{ lib, pkgs, privateForHost, secretForHost, ... }:
let
  # msmtp wants us to use passwordeval (or GNOME keyring) to access the password
  # but it uses popen, which goes through /bin/sh and kills the setuid rights.
  usePasswordEval = false;
in
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
      #logfile        ~/.msmtp.log
      syslog         on
      set_from_header on
      # This causes error "envelope-from address is missing" although it should
      # use the value of the `from` setting - at least that's how I understand
      # the documentation. Anyway, the server will check it so we don't have
      # to be too strict here.
      #allow_from_override off

      # Gmail
      account        mail
      host           ${p.smtpHost}
      port           ${toString p.smtpPort}
      tls_starttls   off
      #NOTE You can set `from` to username+%U@domain to include the name of the user that is calling sendmail
      #     but keep in mind that this can be faked by setting $USER or $LOGNAME.
      from           ${p.from}
      user           ${p.username}
      passwordeval   cat /etc/msmtp-password

      # Set a default account
      account default: mail
    '';
  };

  # default is to set this to root and don't setuid but we need setuid to access the password
  services.mail.sendmailSetuidWrapper = {
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

    serviceConfig.ExecStart = lib.mkIf usePasswordEval
      ("${pkgs.coreutils}/bin/install -C -m 0400 -o msmtp -g msmtp "
      + "${secretForHost}/msmtp-password /etc/msmtp-password");

    script = lib.mkIf (!usePasswordEval) ''
      # We cannot use passwordeval to read the password so we must bake it into the config file.
      umask 077
      t=$(mktemp)
      while read line ; do
        if [[ $line =~ passwordeval ]] ; then # very imprecise but input is known and trusted
          echo "password $(cat ${secretForHost}/msmtp-password)"
        else
          echo "$line"
        fi
      done </etc/msmtprc-without-secrets >"$t"

      install -C -m 0400 -o msmtp -g msmtp "$t" /etc/msmtprc
      rm "$t"
    '';
  };

  environment.etc."msmtprc".target = lib.mkIf (!usePasswordEval) "msmtprc-without-secrets";
}