{ lib, config, ... }@args:
let
  modules = args.modules or (import ./modules.nix {});
in {
  imports = [ modules.snowball-big ];

  services.printing.enable = true;

  sound.enable = true;
  hardware.pulseaudio.enable = true;
}
