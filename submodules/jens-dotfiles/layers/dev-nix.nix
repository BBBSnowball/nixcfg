{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    nix-prefetch-git
    nix-prefetch-github
    nix-index
  ];
}
