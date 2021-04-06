{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";
  inputs.flake-compat.follows = "routeromen/flake-compat";
  inputs.private.url = "path:./private";
  inputs.private.flake = false;
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";

  inputs.dummy.url = "github:BBBSnowball/nixcfg/dummy";
  inputs.routeromen.inputs.private.follows = "dummy";
  inputs.routeromen.inputs.private-nixosvm.follows = "dummy";
  inputs.routeromen.inputs.private-c3pbvm.follows = "dummy";

  outputs = { self, nixpkgs, routeromen, ... }@flakeInputs:
    routeromen.lib.mkFlakeForHostConfig "c3pbvm" "x86_64-linux" ./main.nix flakeInputs;
}
