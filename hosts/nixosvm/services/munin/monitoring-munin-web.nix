{ lib, pkgs, config, privateForHost, secretForHost, ... }:
let
  inherit (privateForHost.mastodon) domain;
  ports = config.networking.firewall.allowedPorts;
  
  creds = "/run/credentials/nginx.service";
in
{
  services.nginx = {
    enable = true;

    virtualHosts."munin.${domain}" = {
      listen = [
        { addr = "0.0.0.0"; port = ports.munin.port; }
      ];

      basicAuthFile = "${creds}/munin_htpasswd";

      locations."/".extraConfig = ''
        rewrite ^/$ munin/ redirect; break;
      '';
      locations."/favicon.ico".extraConfig = ''
        rewrite ^/$ munin/static/favicon.ico redirect; break;
        auth_basic off;
      '';
      locations."/munin/static/".extraConfig = ''
        alias /var/www/munin/static/;
        #expires modified +310s;
      '';
      locations."^~ /munin-cgi/munin-cgi-graph/".extraConfig = ''
        fastcgi_split_path_info ^(/munin-cgi/munin-cgi-graph)(.*);
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_pass unix:/run/munin/fastcgi-graph.sock;
        include ${pkgs.nginx}/conf/fastcgi_params;
      '';
      #locations."@muningraph".extraConfig = ''
      #  fastcgi_split_path_info ^(/munin-cgi/munin-cgi-graph)(.*);
      #  fastcgi_param PATH_INFO $fastcgi_path_info;
      #  fastcgi_pass unix:/run/munin/fastcgi-graph.sock;
      #  include ${pkgs.nginx}/conf/fastcgi_params;
      #'';
      locations."/munin/".extraConfig = ''
        fastcgi_split_path_info ^(/munin)(.*);
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_pass unix:/run/munin/fastcgi-html.sock;
        include ${pkgs.nginx}/conf/fastcgi_params;
      '';

      locations."/mastodon/" = {
        basicAuthFile = "${creds}/munin_htpasswd2";
        alias = "${./munin-mastodon-html}/";
      };
      #locations."~ ^/mastodon/img/df_(abs_)?mstdn-(day|week).png$" = {
      #  basicAuthFile = "${creds}/munin_htpasswd2";
      #  extraConfig = ''
      #    rewrite ^/mastodon/img/(.*[.].png)$ /munin-cgi/munin-cgi-graph/nixosvm/nixosvm/$1;
      #    try_files ${./munin-mastodon-html}/ @muningraph;
      #  '';
      #};
      locations."~ ^/mastodon/img/nixosvm/nixosvm/df_(abs_)?mstdn-(day|week|month|year).png$" = {
        basicAuthFile = "${creds}/munin_htpasswd2";
        extraConfig = ''
          fastcgi_split_path_info ^(/mastodon/img)(.*);
          fastcgi_param PATH_INFO $fastcgi_path_info;
          fastcgi_pass unix:/run/munin/fastcgi-graph.sock;
          include ${pkgs.nginx}/conf/fastcgi_params;
        '';
      };
    };
  };

  #systemd.services.munin-cgi-graph.environment.CGI_DEBUG = "1";

  systemd.services."nginx" = {
    serviceConfig.LoadCredential = [
      "munin_htpasswd:${secretForHost}/munin_htpasswd"
      "munin_htpasswd2:${secretForHost}/munin_htpasswd2"
    ];
  };

  environment.systemPackages = let
    htpasswd = with pkgs; runCommand "htpasswd" {
      # We could use the smaller one from thttpd but container feg is using Apache anyway.
      #pkg = thttpd;
      pkg = apacheHttpd;
    } ''
      mkdir -p $out/bin
      ln -s $pkg/bin/htpasswd $out/bin/htpasswd
    '';
  in [ htpasswd ];

  networking.firewall.allowedPorts.munin = 8203;
}
