{ lib, pkgs, config, privateForHost, secretForHost, ... }:
{
  services.vaultwarden = {
    enable = true;
    #backupDir = "/var/backup/vaultwarden";  # -> handled by "real" backup, see backup.nix
    config = {
      EMAIL_CHANGE_ALLOWED = false;
      SIGNUPS_ALLOWED = false;
      DOMAIN = "https://passwords.vpn.bettina-home.${privateForHost.domain}";

      SMTP_FROM = builtins.replaceStrings ["%U"] ["vaultwarden"] privateForHost.mail.from;
      SMTP_HOST = "127.0.0.1";
      SMTP_PORT = "25";
      SMTP_SECURITY = "off";
      #SMTP_DEBUG = "true";
    };

    # Set ADMIN_TOKEN in vaultwarden.env. Hash it like this:
    #   pwgen -AB0 20 5
    #   nix-shell -p openssl libargon2 --run 'tr -d "\\r\\n" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4'
    #   (see https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page#using-argon2)
    environmentFile = "${secretForHost}/vaultwarden.env";
  };
}
