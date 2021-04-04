{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";
  #inputs.flake-compat.url = "github:edolstra/flake-compat";
  #inputs.flake-compat.flake = false;
  inputs.flake-compat.follows = "routeromen/flake-compat";
  inputs.private.url = "path:./private";
  inputs.private.flake = false;
  #inputs.routeromen.url = "gitlab:snowball/nixos-config-for-routeromen?host=git.c3pb.de";
  #inputs.routeromen.url = "git+ssh://git@git.c3pb.de/snowball/nixos-config-for-routeromen.git";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";
  inputs.routeromen.inputs.private.follows = "private";

  outputs = { self, nixpkgs, routeromen, ... }@flakeInputs:
  (routeromen.lib.mkFlakeForHostConfig "nixosvm" "x86_64-linux" ./main.nix flakeInputs) // {
    nixosModules = {
      container-common = self.lib.withFlakeInputs ./container-common.nix;
    };
  };
}
