rec {
  adminEmail = "admin@example.com";
  userName = "user";
  acmeEmail = "acme@example.com";

  sonline0 = import ../sonline0-shared/sonline0-common.nix;

  inherit (sonline0) infoDomain;

  net = {
    internalPrefix = "1.2.3";
    ip0 = "1.2.3.4";
    ip1 = "1.2.3.5";
    ip2 = "1.2.3.6";
    gw = "1.2.3.7";
    nameservers = [ "1.2.3.8" ];
    ipv6 = "aa:bb::42";
    ipv6_cidr = "aa:bb::0/32";
    ipv6_br84_cidr = "aa:84::0/32";
  };

  trusted-public-keys = [];
}