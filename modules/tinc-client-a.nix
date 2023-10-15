import ./tinc-client-common.part.nix {
  name       = "a";
  extraConfig = ''
    LocalDiscovery=yes
    ConnectTo=sonline
    #ConnectTo=routeromen

    Port 657
  '';
}

