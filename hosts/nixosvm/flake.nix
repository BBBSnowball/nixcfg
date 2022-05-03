{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";
  #inputs.flake-compat.url = "github:edolstra/flake-compat";
  #inputs.flake-compat.flake = false;
  inputs.flake-compat.follows = "routeromen/flake-compat";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, routeromen, ... }@flakeInputs:
  (routeromen.lib.mkFlakeForHostConfig "nixosvm" "x86_64-linux" ./main.nix flakeInputs) // {
    nixosModules = {
      container-common = self.lib.withFlakeInputs ./container-common.nix;
    };
  };
}
