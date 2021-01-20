{
  description = "Config for my NixOS hosts";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";

  #inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.url = "github:BBBSnowball/flake-compat";
  inputs.flake-compat.flake = false;

  inputs.jens-dotfiles.url = "gitlab:jens/dotfiles/cbded47f57fa7c5819709f2a2e97ea29af9b321a?host=git.c3pb.de";
  inputs.jens-dotfiles.flake = false;

  inputs.private.url = "path:./private";
  inputs.private.flake = false;

  #inputs.nix-bundle.url = "github:matthewbauer/nix-bundle";
  inputs.nix-bundle.url = "github:BBBSnowball/nix-bundle";
  inputs.nix-bundle.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, nix-bundle, ... }: let
    nixosSystemModule = path: {
      imports =
        [ (self.lib.provideArgsToModule (self.inputs // { modules = self.nixosModules; inherit self; }) path)
          ({ pkgs, ... }: {
            _file = "${self}/flake.nix#inline-config";
            # Let 'nixos-version --json' know about the Git revision
            # of this flake.
            system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
          })
        ];
    };
  in {
    lib = import ./lib.nix { pkgs = nixpkgs; };

    nixosModules = import ./modules.nix { inherit self; } // {
      hosts-routeromen = nixosSystemModule hosts/routeromen;
    };

    # The common module includes all the settings and modules that I want to apply to all systems.
    nixosModule = self.nixosModules.common;
 
    nixosConfigurations.routeromen = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ self.nixosModules.hosts-routeromen ];
    };
  } // (let
    supportedSystems = [ "x86_64-linux" "i686-linux" "aarch64-linux" ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    stuff = forAllSystems (system: import ./riscv/compiler.nix { inherit nixpkgs system; });
  in {
    packages = forAllSystems (system: with stuff.${system}; {
      rustc-gd32 = rustc; cargo-gd32 = cargo; gcc-gd32 = gcc; binutils-gd32 = binutils; openocd-gd32 = openocd-nuclei; gdb-gd32 = gdb-nuclei;
    });
    apps = forAllSystems (system: {
      gcc-gd32   = { type = "app"; program = "${self.packages.${system}.gcc-gd32}/bin/gcc"; };
      openocd-gd32 = { type = "app"; program = "${self.packages.${system}.openocd-gd32}/bin/openocd"; };
      gdb-gd32   = { type = "app"; program = "${self.packages.${system}.gdb-gd32}/bin/gdb"; };
      rustc-gd32 = { type = "app"; program = "${self.packages.${system}.rustc-gd32}/bin/rustc"; };
      cargo-gd32 = { type = "app"; program = "${self.packages.${system}.cargo-gd32}/bin/cargo"; };

      bundle = { type = "app"; program = builtins.toString (with nixpkgs.legacyPackages.${system}; writeShellScript "nix-bundle-routeromen" ''
        if [ -z "$1" ] ; then
          echo "Usage: $0 program" >&2
          echo "  program: $(nix-instantiate --eval -E 'let x = builtins.getFlake "${toString self}"; in builtins.attrNames x.apps.${system}')"
          exit 1
        else
          nix-build -E 'let x = builtins.getFlake "${toString self}"; in x.defaultBundler { system = "${system}"; program = with x.apps.${system}; ('"$1"').program; rsyncable = true; }'
        fi
      ''); };
    });
    devShells = forAllSystems (system: with self.packages.${system}; with nixpkgs.legacyPackages.${system}; {
      gd32 = mkShell {
        buildInputs = [ gcc-gd32 binutils-gd32 rustc-gd32 cargo-gd32 ] ++ [ gcc lld_11 ];
      };
    });
    inherit (nix-bundle) bundlers defaultBundler;
  });
}
