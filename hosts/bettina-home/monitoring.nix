{ config, ... }:
{
  services.munin-cron.enable = true;
  services.munin-cron.hosts = ''
    [${config.networking.hostName}]
    address localhost
  '';
  services.munin-node.enable = true;
}