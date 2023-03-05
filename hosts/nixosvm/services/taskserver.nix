{ lib, config, privateForHost, ... }:
{
  services.taskserver.enable = true;
  services.taskserver.fqdn = lib.fileContents "${privateForHost}/taskserver-fqdn.txt";
  services.taskserver.listenHost = "::";
  services.taskserver.organisations.snente.users = [ "snowball" "ente" ];
}
