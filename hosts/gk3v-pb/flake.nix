{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  #inputs.routeromen.url = "path:../..";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-registry.url = "github:NixOS/flake-registry";
  inputs.flake-registry.flake = false;

  #inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs";

  inputs.dummy.url = "github:BBBSnowball/nixcfg/dummy";
  inputs.routeromen.inputs.private.follows = "dummy";
  inputs.routeromen.inputs.private-nixosvm.follows = "dummy";
  inputs.routeromen.inputs.private-c3pbvm.follows = "dummy";
  inputs.private.follows = "dummy";

  outputs = { self, nixpkgs, routeromen, private, ... }@flakeInputs:
    routeromen.lib.mkFlakeForHostConfig "gk3v-pb" "x86_64-linux" ./main.nix flakeInputs;
}
