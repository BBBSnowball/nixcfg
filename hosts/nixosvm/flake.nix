{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  #inputs.flake-compat.url = "github:edolstra/flake-compat";
  #inputs.flake-compat.flake = false;
  inputs.flake-compat.follows = "routeromen/flake-compat";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixpkgs-24-05.url = "github:NixOS/nixpkgs/nixos-24.05";

  # Magpie needs Python 2.7 and some packages for that are marked broken on newer nixpkgs.
  inputs.nixpkgs-notes.url = "github:NixOS/nixpkgs/da7f4c4842520167f65c20ad75ecdbd14e27ae91";
  # selfoss is completely broken (argument names have changed in PHP 7 but also it doesn't find its own properties on its view object)
  inputs.nixpkgs-rss.url = "github:NixOS/nixpkgs/da7f4c4842520167f65c20ad75ecdbd14e27ae91";

  outputs = { self, nixpkgs, routeromen, ... }@flakeInputs:
  (routeromen.lib.mkFlakeForHostConfig "nixosvm" "x86_64-linux" ./main.nix flakeInputs) // {
    nixosModules = {
      container-common = self.lib.withFlakeInputs ./container-common.nix;
    };
  };
}
