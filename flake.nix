{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";
  inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.flake = false;
  inputs.rockpro64Config.url = "github:BBBSnowball/nixos-installer-rockpro64";
  inputs.rockpro64Config.inputs.nixpkgs.follows = "nixpkgs";
  #inputs.routeromen.url = "gitlab:snowball/nixos-config-for-routeromen?host=git.c3pb.de";
  inputs.routeromen.url = "git+ssh://git@git.c3pb.de/snowball/nixos-config-for-routeromen.git";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";
  inputs.ldap-to-ssh.url = "gitlab:snowball/ldap-to-ssh/a545515d943493bba2be216b58c3ff9b561d3463?host=git.c3pb.de";
  inputs.flake-registry.url = "github:NixOS/flake-registry";
  inputs.flake-registry.flake = false;

  outputs = { self, nixpkgs, routeromen, ... }@flakeInputs: let
    withFlakeInputs = routeromen.lib.provideArgsToModule (flakeInputs // { inherit withFlakeInputs; });
  in {
    nixosModule = withFlakeInputs ./main.nix;
    nixosConfigurations.rockpro64-snowball = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules =
        [ self.nixosModule
          ({ pkgs, ... }: {
            # Let 'nixos-version --json' know about the Git revision
            # of this flake.
            system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;

            #NOTE Those will work similar to withFlakeInputs but can easily cause infinite recursion, e.g. when used inside `imports`.
            #_module.args = builtins.removeAttrs flakeInputs ["self" "nixpkgs"];
            #_module.args.flakeInputs = flakeInputs;
            #_module.args = { inherit rockpro64Config; };

            _file = "${self}/flake.nix#inline-config";
          })
        ];
    };

  };
}
