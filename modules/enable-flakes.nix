{ config, pkgs, lib, ... }@args:
with lib;
{
  # see https://www.tweag.io/blog/2020-07-31-nixos-flakes/
  #config.nix.package = pkgs.nixFlakes; # -> not required anymore
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

  options.addCurrentNixpkgsToNixPath = lib.mkOption {
    type = types.bool;
    default = true;
    example = false;
    description = ''
      Change NIX_PATH to include the current nixpkgs for <nixpkgs.

      That way, any tool or derivation that uses <nixpkgs> will use the same version of nixpkgs
      as the current system and thereby they are likely to use versions of packages
      that are already available in the local nix store.
    '';
  };

  config.nix.registry.nixpkgs = lib.mkIf config.addCurrentNixpkgsToRegistry (if args ? nixpkgs
    then { flake = args.nixpkgs; }
    else { to.type = "path"; to.path = toString <nixpkgs>; });

  config.environment.etc.current-nixpkgs.source = args.nixpkgs or <nixpkgs>;

  config.nix.nixPath = lib.mkIf config.addCurrentNixpkgsToNixPath [
    "nixpkgs=/etc/current-nixpkgs"
    # keep the other default values
    "nixos-config=/etc/nixos/configuration.nix"
    "/nix/var/nix/profiles/per-user/root/channels"
  ];
}
