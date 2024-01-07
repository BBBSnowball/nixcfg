{ ... }:
{
  services.nginx = {
    enable = true;
    virtualHosts."default" = {
      #root = "/var/www/default";
      root = ./html;

      locations."/index.html".extraConfig = ''
        # only cache for a short time and only in memory
        # so we don't need manual updates and we notice
        # when network is down
        expires 60s;
        add_header Cache-Control "no-cache";
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
