# nixos-container update matrix-test --config-file container-matrix-test.nix
{ config, lib, pkgs, ... }:

with lib;

{ boot.isContainer = true;
  networking.hostName = mkDefault "matrix-test";
  networking.useDHCP = false;
  system.stateVersion = "19.03";

  imports = [
    ./autossh.nix
    ./matrix-synapse.nix
    ./mautrix-telegram
    ./matrix-edi.nix
  ];

  services.matrix-synapse.server_name = "test." + (lib.fileContents ../private/trueDomain.txt);
}
