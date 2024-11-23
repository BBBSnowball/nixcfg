{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs";
  inputs.nixpkgs-ollama.url = "github:NixOS/nixpkgs";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-registry.url = "github:NixOS/flake-registry";
  inputs.flake-registry.flake = false;
  inputs.nixos-hardware.url = "github:NixOS/nixos-hardware";

  outputs = { self, nixpkgs, routeromen, ... }@flakeInputs:
    routeromen.lib.mkFlakeForHostConfig "fw" "x86_64-linux" ./main.nix flakeInputs;
}
