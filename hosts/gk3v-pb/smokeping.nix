{ ... }:
{
  imports = [
    ../routeromen/smokeping.nix
  ];

  services.smokeping.nameserver = "192.168.178.1";

  # open HTTP server to local network (instead of only localhost)
  services.smokeping.host = null;
  networking.firewall.allowedTCPPorts = [
    8081
  ];
}
