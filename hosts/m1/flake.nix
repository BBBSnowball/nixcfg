{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-registry.url = "github:NixOS/flake-registry";
  inputs.flake-registry.flake = false;
  inputs.nixos-hardware.url = "github:NixOS/nixos-hardware";
  inputs.nixos-m1.url = "github:tpwrules/nixos-m1";

  outputs = { self, nixpkgs, routeromen, ... }@flakeInputs:
    routeromen.lib.mkFlakeForHostConfig "m1" "aarch64-linux" ./main.nix flakeInputs;
}
