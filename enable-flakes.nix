{ pkgs, lib, ... }@args:
with lib;
{
  # see https://www.tweag.io/blog/2020-07-31-nixos-flakes/
  config.nix.package = pkgs.nixUnstable;
  config.nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  options.addCurrentNixpkgsToRegistry = lib.mkOption {
    type = types.bool;
    default = true;
    example = false;
    description = ''
      Register nixpkgs in the flake registry using the version that is used to build the system.

      That way, many invocations of flakes will use the same version of nixpkgs
      as the current system and thereby they are likely to use versions of packages
      that are already available in the local nix store.
    '';
  };

  config.nix.registry.nixpkgs = if args ? nixpkgs
    then { flake = args.nixpkgs; }
    else { to.type = "path"; to.path = toString <nixpkgs>; };
}
