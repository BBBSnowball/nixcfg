{ lib, pkgs, config, privateForHost, secretForHost, ... }:
{
  services.vaultwarden = {
    enable = true;
    backupDir = "/var/backup/vaultwarden";
    config = {
      EMAIL_CHANGE_ALLOWED = false;
      SIGNUPS_ALLOWED = false;
      DOMAIN = "https://passwords-vpn.bettina-home.${privateForHost.domain}";
      USE_SENDMAIL = true;
      SMTP_FROM = builtins.replaceStrings ["%U"] ["vaultwarden"] privateForHost.mail.from;
      SMTP_DEBUG = true;  #FIXME remove
    };
    #environmentFile = "/run/credentials/vaultwarden.service/secret";
    environmentFile = "${secretForHost}/vaultwarden.env";
  };

  # Set ADMIN_TOKEN in vaultwarden.env. Hash it like this:
  #   pwgen -AB0 20 5
  #   nix-shell -p openssl libargon2 --run 'tr -d "\\r\\n" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4'
  #   (see https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page#using-argon2)
  #systemd.services.vaultwarden.serviceConfig.LoadCredential = [ "secret:${secretForHost}/vaultwarden.env" ];

  # make sendmail available in the service
  systemd.services.vaultwarden.path = [ "/run/wrappers/bin" "/run/wrappers" ];
  #systemd.services.vaultwarden.serviceConfig.BindPaths = [
  #  "/run/wrappers/bin/sendmail"
  #  "/etc/msmtprc"
  #];
  # This breaks setuid for sendmail so we disable it.
  systemd.services.vaultwarden.serviceConfig.PrivateDevices = lib.mkForce false;

  # create backup directory
  systemd.services.backup-vaultwarden.serviceConfig.ExecStartPre = "+${pkgs.coreutils}/bin/install "
    + "-d -m 0700 -o ${config.users.users.vaultwarden.name} ${config.services.vaultwarden.backupDir}";
}
