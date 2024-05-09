{ ... }:
{
  imports = [
    ../routeromen/smokeping.nix
  ];

  # open HTTP server to local network (instead of only localhost)
  services.smokeping.host = null;
  networking.firewall.allowedTCPPorts = [
    8081
  ];
}
