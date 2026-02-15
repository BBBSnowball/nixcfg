rec {
  vmNumber = 42;
  adminEmail = "admin@example.com";

  sonline0 = import ../sonline0-shared/sonline0-common.nix;

  inherit (sonline0) trueDomain serverExternalIp;

  mumble-domain-c3pb = "m.example.com";
}