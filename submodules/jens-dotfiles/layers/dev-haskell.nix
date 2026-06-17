{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    cabal-install
    #haskell-language-server
    haskellPackages.hoogle
    ghcid
    #haskellPackages.threadscope
  ];

  services.hoogle = {
    enable = true;
    packages = hp: with hp; [
      hashable
      heaps
      network
      #quasar
      #quasar-network
      unordered-containers
    ];
  };
}
