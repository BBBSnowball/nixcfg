{ ... }:
{
  services.nginx = {
    enable = true;
    virtualHosts."default" = {
      #root = "/var/www/default";
      root = ./html;
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
