{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  #inputs.routeromen.url = "path:../..";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-registry.url = "github:NixOS/flake-registry";
  inputs.flake-registry.flake = false;

  #inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs, routeromen, ... }@flakeInputs:
    routeromen.lib.mkFlakeForHostConfig "gk3v-pb" "x86_64-linux" ./main.nix flakeInputs;
}
