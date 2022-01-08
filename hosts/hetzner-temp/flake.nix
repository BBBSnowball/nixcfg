{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-registry.url = "github:NixOS/flake-registry";
  inputs.flake-registry.flake = false;

  inputs.dummy.url = "github:BBBSnowball/nixcfg/dummy";
  inputs.routeromen.inputs.private.follows = "dummy";
  inputs.routeromen.inputs.private-nixosvm.follows = "dummy";
  inputs.routeromen.inputs.private-c3pbvm.follows = "dummy";
  inputs.routeromen.inputs.private-gk3v-pb.follows = "dummy";
  inputs.private.follows = "dummy";

  outputs = { self, nixpkgs, routeromen, private, ... }@flakeInputs:
    routeromen.lib.mkFlakeForHostConfig "hetzner-temp" "x86_64-linux" ./main.nix flakeInputs;
}
