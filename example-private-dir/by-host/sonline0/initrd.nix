{ testInQemu }:
{
  secretDir = "/secret";
  port = 22;
  authorizedKeys = [
    "ssh-rsa nosuchkey"
  ];
  disk-ids = [ "abc" ];
}