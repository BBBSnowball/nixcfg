{ pkgs, nixpkgs-mongodb, ... }:
{
  # Hydra doesn't build it because SSPL has more restrictions than AGPL and the build takes for ages.
  # -> It's not the best idea to pin this but we don't have any other good option, I think.
  nixpkgs.overlays = [ (final: prev: {
    mongodb = nixpkgs-mongodb.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mongodb-3_4;
    #mongodb = (import nixpkgs-mongodb {
    #  config.allowUnfreePredicate = x: true;
    #  system = pkgs.stdenv.hostPlatform.system;
    #}).mongodb;
  }) ];
}
