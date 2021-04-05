# extra-container create container-matrix-test.nix --update-changed
{ config, lib, pkgs, ... }:

with lib;

{
  containers.matrix-test = {
    privateNetwork = false;
    config = {
      boot.isContainer = true;
      networking.hostName = mkDefault "matrix-test";
      networking.useDHCP = false;
      system.stateVersion = "19.03";

      imports = [
        ./autossh.nix
        ./matrix-synapse.nix
        ./mautrix-telegram
        ./matrix-edi.nix
      ];

      services.matrix-synapse.isTestInstance = true;
    };
  };
}
