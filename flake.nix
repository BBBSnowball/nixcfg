{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";
  inputs.rockpro64Config.url = "github:BBBSnowball/nixos-installer-rockpro64";
  inputs.rockpro64Config.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, rockpro64Config }@flakeInputs: let
    provideArgs = args: f: with (if nixpkgs.lib.isFunction f then { f2 = f; meta = {}; } else { f2 = import f; meta._file = builtins.toString f; });
      nixpkgs.lib.setFunctionArgs (x: f2 (x // args) // meta) (builtins.removeAttrs (nixpkgs.lib.functionArgs f2) (builtins.attrNames args));
    withFlakeInputs = provideArgs flakeInputs;
  in {

    nixosConfigurations.rockpro64-snowball = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules =
        [ (withFlakeInputs ./configuration.nix)
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
