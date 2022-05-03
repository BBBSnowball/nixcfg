{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";
  inputs.rockpro64Config.url = "github:BBBSnowball/nixos-installer-rockpro64";
  inputs.rockpro64Config.inputs.nixpkgs.follows = "nixpkgs";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  #inputs.routeromen.url = "path:../..";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";
  inputs.ldap-to-ssh.url = "gitlab:snowball/ldap-to-ssh/a545515d943493bba2be216b58c3ff9b561d3463?host=git.c3pb.de";
  inputs.flake-registry.url = "github:NixOS/flake-registry";
  inputs.flake-registry.flake = false;

  inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs, routeromen, nixpkgs-unstable, ... }@flakeInputs:
    routeromen.lib.mkFlakeForHostConfig "rockpro64-snowball" "aarch64-linux" ./main.nix flakeInputs
    // {
      packages.aarch64-linux.htop = let
        system = "aarch64-linux";
        f = import ./htop-with-sensors.nix { inherit system nixpkgs-unstable; };
        super = nixpkgs.legacyPackages.${system};
        self = super // (f self super);
      in self.htop;
    };
}
