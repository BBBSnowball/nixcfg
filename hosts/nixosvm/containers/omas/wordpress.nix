{ config, pkgs, domain, ports, ... }:
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
    '';

    plugins = {
      #inherit (pkgs.myWordpressPlugins);
    };

    themes = {
      inherit (pkgs.myWordpressThemes)
        neve twentyseventeen;
    };
  };

  services.mysql.settings.mysqld.skip-networking = true;
}
