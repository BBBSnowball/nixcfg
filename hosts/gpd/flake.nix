{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-registry.url = "github:NixOS/flake-registry";
  inputs.flake-registry.flake = false;

  outputs = { self, nixpkgs, routeromen, ... }@flakeInputs:
    routeromen.lib.mkFlakeForHostConfig "gpd" "x86_64-linux" ./main.nix flakeInputs;
}
