{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs";
  inputs.nixpkgs-ollama.url = "github:NixOS/nixpkgs";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-registry.url = "github:NixOS/flake-registry";
  inputs.flake-registry.flake = false;
  inputs.nixos-hardware.url = "github:NixOS/nixos-hardware";
  inputs.lanzaboote.url = "github:nix-community/lanzaboote/v0.3.0";
  inputs.lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
  inputs.disko.url = "github:nix-community/disko/v1.6.1";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, routeromen, ... }@flakeInputs:
    routeromen.lib.mkFlakeForHostConfig "ug1" "x86_64-linux" ./main.nix flakeInputs;
}
