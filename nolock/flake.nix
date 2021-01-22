{
  description = "Config for my NixOS hosts";

  inputs.nixpkgs.url = "nixpkgs";

  #inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.url = "github:BBBSnowball/flake-compat";
  inputs.flake-compat.flake = false;

  inputs.jens-dotfiles.url = "gitlab:jens/dotfiles/cbded47f57fa7c5819709f2a2e97ea29af9b321a?host=git.c3pb.de";
  inputs.jens-dotfiles.flake = false;

  inputs.private.url = "nixpkgs"; # just a dummy, here
  inputs.private.flake = false;

  #inputs.nix-bundle.url = "github:matthewbauer/nix-bundle";
  inputs.nix-bundle.url = "github:BBBSnowball/nix-bundle";
  inputs.nix-bundle.inputs.nixpkgs.follows = "nixpkgs";

  # Do not eta-reduce this (because that would yield "expected a function but got a thunk").
  outputs = args: (import ../flake.nix).outputs args;
} 
