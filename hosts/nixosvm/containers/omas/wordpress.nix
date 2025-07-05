{ config, pkgs, domain, oldDomain, ports, ... }:
let
  name = "omas";
  hostName = domain;
  port = ports.omas-wordpress.port;

  wp-root = config.services.nginx.virtualHosts.${hostName}.root;
  wp-cmd = pkgs.writeShellScriptBin "wp-${name}" ''
    exec sudo -u wordpress -- ${pkgs.wp-cli}/bin/wp --path=${wp-root} "$@"
  '';

  fetchLanguage = { language, hash ? "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }:
  pkgs.stdenv.mkDerivation {
    name = "wordpress-language-${language}";
    src = pkgs.fetchurl {
      url = "https://de.wordpress.org/wordpress-${pkgs.wordpress.version}-${language}.tar.gz";
      name = "wordpress-${pkgs.wordpress.version}-${language}.tar.gz";
      inherit hash;
    };
    installPhase = "mkdir -p $out; cp -r ./wp-content/languages/* $out/";
  };
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
    '';

    plugins = {
      #inherit (pkgs.myWordpressPlugins);
    };

    themes = {
      inherit (pkgs.myWordpressThemes)
        neve twentyseventeen;
    };

    languages = [ (fetchLanguage {
      language = "de_DE";
      #hash = "sha256-21wyaomIfkhjbddIRhFofcfZn7FoitSTi1r1jx9ULXI=";
      hash = "sha256-IcYbNy2c/EyYfQKQmnYIcMHo6anV0ipj3bAZX0TSYkM=";
    }) ];
  };

  services.mysql.settings.mysqld.skip-networking = true;
}
