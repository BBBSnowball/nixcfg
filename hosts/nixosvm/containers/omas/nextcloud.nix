{ pkgs, config, domain, ports, ... }:
let
  hostName = "cloud.${domain}";
  port = ports.omas-nextcloud.port;
in
{
  services.nginx.virtualHosts.${hostName} = {
    listen = [
      { addr = "0.0.0.0"; inherit port; }
    ];
  };

  services.nextcloud = {
    enable = true;
    autoUpdateApps.enable = true;
    config.adminpassFile = "/run/credentials/nextcloud-setup.service/secret_nextcloud-admin-password";
    # Name must be the same regardless of which service is using it.
    secretFile = "/run/nextcloud/secret.conf";
  
    # We have to manually specify the version, so we can ensure that migrations run between major upgrades.
    package = pkgs.nextcloud31;

    hostName = hostName;

    # not needed and should be more secure without it
    # -> Well, could be useful here.
    #enableImagemagick = false;

    maxUploadSize = "100M";
  
    config = {
      dbhost = "/run/postgresql";
      dbtype = "pgsql";
    };

    settings = {
       mail_smtpmode = "sendmail";
       mail_sendmailmode = "pipe";
       mail_from_address = "noreply";
       mail_domain = domain;

       settings.enabledPreviewProviders = [
         #"OC\\Preview\\BMP"
         #"OC\\Preview\\GIF"
         "OC\\Preview\\JPEG"
         #"OC\\Preview\\Krita"
         "OC\\Preview\\MarkDown"
         #"OC\\Preview\\MP3"
         #"OC\\Preview\\OpenDocument"
         "OC\\Preview\\PNG"
         "OC\\Preview\\TXT"
         #"OC\\Preview\\XBitmap"
         "OC\\Preview\\HEIC"
       ];
    };

    extraAppsEnable = true;
    extraApps = {
      inherit (config.services.nextcloud.package.packages.apps)
        news contacts calendar tasks
        forms
        groupfolders
        #memories  # photos  -> too many errors in log
        polls
        #whiteboard  # -> needs an additional server
        #unroundedcorners
        quota_warning
        #onlyoffice  # -> needs an additional server
        end_to_end_encryption
        ;
    };
  };

  systemd.services."nextcloud-setup" = {
    serviceConfig.LoadCredential = [ "secret_nextcloud-admin-password" "secret_nextcloud-config" ];
    after = [ "postgresql.service" ];
    serviceConfig.ExecStartPre = [
      "+${pkgs.coreutils}/bin/install -D -m 0400 -o nextcloud %d/secret_nextcloud-config /run/nextcloud/secret.conf"
    ];
  };

  systemd.services."phpfpm-nextcloud" = {
    serviceConfig.LoadCredential = [ "secret_nextcloud-config" ];
    serviceConfig.ExecStartPre = [
      "${pkgs.coreutils}/bin/install -D -m 0400 -o nextcloud %d/secret_nextcloud-config /run/nextcloud/secret.conf"
    ];
    path = with pkgs; [ exiftool ];
  };
}
