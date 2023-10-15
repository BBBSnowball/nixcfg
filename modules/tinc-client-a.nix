import ./tinc-client-common.part.nix {
  name       = "a";
  extraConfig = ''
    ConnectTo=sonline
    #ConnectTo=routeromen

    Port 657
  '';
}

