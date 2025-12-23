{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-registry.url = "github:NixOS/flake-registry";
  inputs.flake-registry.flake = false;
  inputs.nixos-hardware.url = "github:NixOS/nixos-hardware";
  inputs.disko.url = "github:nix-community/disko/v1.2.0";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixpkgs-mongodb.url = "github:NixOS/nixpkgs/c6f52ebd45e5925c188d1a20119978aa4ffd5ef6";  # update triggers long rebuild

  outputs = { self, nixpkgs, routeromen, ... }@flakeInputs:
    routeromen.lib.mkFlakeForHostConfig "bettina-home" "x86_64-linux" ./main.nix flakeInputs;
}
