import ./tinc-client-common.part.nix {
  name       = "bbbsnowball";
  extraConfig = ''
    ConnectTo=sonline
    ConnectTo=routeromen
  '';
}

