{ lib, pkgs, config, domain, ports, reverse_proxy_ip, ... }:
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
    config.adminpassFile = "secret_nextcloud-admin-password";
    secretFile = "secret_nextcloud-config";
  
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

       enabledPreviewProviders = [
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
       trusted_proxies = [ reverse_proxy_ip ];
       overwritehost = hostName;
       #trusted_domains = [ hostName ];
       maintenance_window_start = 2;  # 2 am, UTC
       default_phone_region = "DE";
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

      theming_customcss = pkgs.fetchNextcloudApp {
        url = "https://github.com/nextcloud-releases/theming_customcss/releases/download/v1.18.0/theming_customcss.tar.gz";
        #url = "https://github.com/nextcloud/theming_customcss/archive/refs/tags/v1.18.0.tar.gz";
        hash = "sha256-MsF+im9yCt7bRNIE8ait0wxcVzMXsHMNbp+IIzY/zJI=";
        license = "agpl3Plus";
      };
    };

    # Admin interface was complaining about too small cache.
    phpOptions."opcache.interned_strings_buffer" = "23";
    # Admin interface was complaining about not enough memory.
    phpOptions.memory_limit = lib.mkForce "512M";  # default is equal to max upload file size
  };

  systemd.services."nextcloud-setup" = {
    after = [ "postgresql.service" ];

    script = let
      css = pkgs.writeText "nextcloud_custom.css" ''
        #body-public:has(input#initial-state-calendar-is_embed) {
          #header {display: none}
          #content-vue {
            margin-top: var(--body-container-margin);
            height: calc(100% - var(--body-container-margin) * 2);
          }
        }
      '';
      hash = builtins.substring 0 32 (builtins.replaceStrings ["/nix/store/"] [""] css.outPath);
      occ = lib.getExe config.services.nextcloud.occ;
    in ''
      ${occ} config:app:set theming_customcss customcss --value "$(cat ${css})"
      ${occ} config:app:set theming_customcss cachebuster --value "${hash}"
    '';
  };

  systemd.services."phpfpm-nextcloud" = {
    path = with pkgs; [ exiftool ];
  };
}
