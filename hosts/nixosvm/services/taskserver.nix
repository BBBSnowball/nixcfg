{ lib, config, private, ... }:
let
  privateForHost = "${private}/by-host/${config.networking.hostName}";
in
{
  services.taskserver.enable = true;
  services.taskserver.fqdn = lib.fileContents "${privateForHost}/taskserver-fqdn.txt";
  services.taskserver.listenHost = "::";
  services.taskserver.organisations.snente.users = [ "snowball" "ente" ];
}
