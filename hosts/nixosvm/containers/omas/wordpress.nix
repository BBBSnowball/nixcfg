{ pkgs, domain, ports, ... }:
let
  name = "omas";
  hostName = domain;
  port = ports.omas-wordpress.port;

  wp-cmd = pkgs.writeShellScriptBin "wp-${name}" ''
    exec sudo -u wordpress -- ${pkgs.wp-cli}/bin/wp --path=${config.services.nginx.virtualHosts.${hostName}.root} "$@"
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
      locations."/extra-fonts" = {
        #alias = "/var/www/extra-fonts";
        alias = "/var/www%{REQUEST_URI}";  # oh, well... ugly hack!
        extraConfig = ''
          Require all granted
        '';
      };
    };

    plugins = {
      #inherit (pkgs.myWordpressPlugins);
    };

    themes = {
      inherit (pkgs.myWordpressThemes)
        neve;
    };
  };
}
