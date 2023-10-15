import ./tinc-client-common.part.nix {
  name       = "bbbsnowball";
  extraConfig = ''
    LocalDiscovery=yes
    ConnectTo=sonline
    ConnectTo=routeromen
  '';
}

