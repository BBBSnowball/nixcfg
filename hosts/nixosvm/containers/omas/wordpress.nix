{ config, pkgs, domain, oldDomain, ports, ... }:
let
  name = "omas";
  hostName = domain;
  port = ports.omas-wordpress.port;

  wp-root = config.services.nginx.virtualHosts.${hostName}.root;
  wp-cmd = pkgs.writeShellScriptBin "wp-${name}" ''
    exec sudo -u wordpress -- ${pkgs.wp-cli}/bin/wp --path=${wp-root} "$@"
  '';
in
{
  imports = [
    ../parts/wordpress-pkgs.nix
  ];

  services.nginx.virtualHosts.${hostName} = {
    listen = [
      { addr = "0.0.0.0"; inherit port; }
    ];
  };
  #services.nginx.virtualHosts."www.${hostName}" = config.services.nginx.virtualHosts.${hostName};
  services.nginx.virtualHosts."www.${hostName}" = {
    listen = [
      { addr = "0.0.0.0"; inherit port; }
    ];
    extraConfig = ''
      rewrite ^/(.*)$ http://${hostName}/$1 redirect;
    '';
  };

  environment.systemPackages = with pkgs; [
    wp-cmd unzip
  ];

  services.wordpress.webserver = "nginx";

  services.wordpress.sites.${hostName} = {
    database = {
      socket = "/run/mysqld/mysqld.sock";
      name = "wordpress";
      createLocally = true;
    };

    virtualHost = {
      adminAddr = "postmaster@${domain}";
      serverAliases = [ hostName ];
      listen = [ { port = ports."${name}-wp".port; } ];
    };

    extraConfig = ''
      if (strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false)
        $_SERVER['HTTPS']='on';

      # login will be broken after changing the domain unless we set these variables
      # see https://developer.wordpress.org/advanced-administration/upgrade/migrating/
      define('WP_HOME', 'https://${hostName}');
      define('WP_SITEURL', 'https://${hostName}');

      # avoid warning because Wordpress cannot update itself (obviously)
      define('WPMU_PLUGIN_DIR', '${pkgs.writeTextFile {
        name = "wordpress-must-use";
        destination = "/disable-site-status-tests.php";
        # see https://plugins.trac.wordpress.org/browser/disable-wordpress-updates/trunk/disable-updates.php
        # and https://developer.wordpress.org/reference/hooks/site_status_tests/#comment-3216
        # and https://stackoverflow.com/questions/21449197/wordpress-configuration-via-add-filter/35202129#35202129
        # and /nix/store/j49216mc1i89.../share/wordpress/wp-admin/includes/class-wp-site-health.php
        text = ''
          <?php
          function remove_background_updates_test($tests) {
            unset( $tests['async']['background_updates'] );
            unset( $tests['direct']['plugin_theme_auto_updates'] );
            unset( $tests['direct']['update_temp_backup_writable'] );
            return $tests;
          }
          add_filter( 'site_status_tests', 'remove_background_updates_test' );
          ?>
        '';
      }}');

      # Astra theme tries to access filesystem "for managing local doc files" and this page will fail
      # with an internal error when it tries to do so with FTP: /wp-admin/admin.php?page=astra
      define('FS_METHOD', 'direct');
      # Let's tell Wordpress that it cannot write to the filesystem because Nix store is readonly anyway.
      define( 'DISALLOW_FILE_MODS', true );
    '';

    plugins = {
      inherit (pkgs.myWordpressPlugins)
      ultimate-addons-for-gutenberg
      elementor
      real-cookie-banner
      backwpup
      ;
    };

    themes = {
      inherit (pkgs.myWordpressThemes)
      #neve
      #twentyseventeen
      twentytwentyfive
      astra
      ;
    };

    languages = with pkgs.wordpressPackages.languages; [ de_DE ];

    # This would be put into `settings`, which is not what we want.
    #poolConfig.phpOptions = ''
    #  extension=${pkgs.phpExtensions.imagick}/lib/php/extensions/imagick.so
    #'';
  };

  services.mysql.settings.mysqld.skip-networking = true;

  services.phpfpm.pools."wordpress-${hostName}".phpOptions = ''
    extension=${pkgs.phpExtensions.imagick}/lib/php/extensions/imagick.so
  '';
}
