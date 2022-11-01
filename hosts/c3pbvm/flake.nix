{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
  inputs.flake-compat.follows = "routeromen/flake-compat";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixpkgsLetsmeet.url = "github:NixOS/nixpkgs/nixos-21.11";

  outputs = { self, nixpkgs, routeromen, ... }@flakeInputs:
    routeromen.lib.mkFlakeForHostConfig "c3pbvm" "x86_64-linux" ./main.nix flakeInputs
    // {
      packages.x86_64-linux = let
        #private = routeromen.inputs.private;
        private = nixpkgs.legacyPackages.x86_64-linux.runCommand "dummy-private" {} ''
          mkdir $out
          echo 1.2.3.4 >$out/serverExternalIp.txt
        '';
        pkgs = import nixpkgs { system = "x86_64-linux"; overlays = [ (import ./c3pb/letsmeet/overlay.nix private) ]; };
      in {
        inherit (pkgs) edumeet-app edumeet-server;
      };
    };
}
