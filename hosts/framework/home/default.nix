{ home-manager, privateForHost, ... }:
{
  imports = [
    home-manager.nixosModules.home-manager
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.user = ./home.nix;
  home-manager.extraSpecialArgs = { inherit privateForHost; };
}
