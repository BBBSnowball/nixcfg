{ pkgs, nixpkgs-ollama, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  pkg = nixpkgs-ollama.legacyPackages."${system}".ollama;
in
{
  services.ollama = {
    enable = true;
    package = pkg;
  };

  users.users.user2.packages = [ pkg ];
}
