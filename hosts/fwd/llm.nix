{ pkgs, nixpkgs-unstable, ... }:
let
  pkgs-unstable = nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  services.ollama = rec {
    enable = true;
    acceleration = "rocm";
    #acceleration = false;
    package = if acceleration != false
    then pkgs-unstable."ollama-${acceleration}"
    else pkgs-unstable.ollama;
  };

  services.nextjs-ollama-llm-ui = {
    enable = true;
  };

  #services.tabby.enable = true;

  environment.systemPackages = with pkgs; [
    nvtopPackages.amd
    radeontop
    amdgpu_top
  ];
}
