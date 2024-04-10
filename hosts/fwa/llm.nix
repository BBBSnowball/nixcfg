{ pkgs, nixpkgs-ollama, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  services.ollama = {
    enable = true;
    package = nixpkgs-ollama.legacyPackages."${system}".ollama;
  };
}
