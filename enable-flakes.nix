{ pkgs, ... }:
{
  # see https://www.tweag.io/blog/2020-07-31-nixos-flakes/
  nix.package = pkgs.nixUnstable;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
}
