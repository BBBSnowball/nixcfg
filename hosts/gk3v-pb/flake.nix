{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  #inputs.routeromen.url = "path:../..";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-registry.url = "github:NixOS/flake-registry";
  inputs.flake-registry.flake = false;
  inputs.nixpkgs-unstable.follows = "routeromen/nixpkgs-unstable";
  # Hydra doesn't build it because SSPL has more restrictions than AGPL and the build takes for ages.
  # -> It's not the best idea to pin this but we don't have any other good option, I think.
  inputs.nixpkgs-mongodb.url = "github:NixOS/nixpkgs/bd1cde45c77891214131cbbea5b1203e485a9d51";

  #inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs, routeromen, ... }@flakeInputs:
    routeromen.lib.mkFlakeForHostConfig "gk3v-pb" "x86_64-linux" ./main.nix flakeInputs;
}
