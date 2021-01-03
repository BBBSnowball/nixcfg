{
  services.taskserver.enable = true;
  services.taskserver.fqdn = builtins.readFile ./private/taskserver-fqdn.txt;
  services.taskserver.listenHost = "::";
  services.taskserver.organisations.snente.users = [ "snowball" "ente" ];
}
