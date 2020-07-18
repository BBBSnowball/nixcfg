{ pkgs, config, lib, ... }:
{
  imports = [
    ./autossh.nix
    #./mumbleweb.nix
    ./dinge-info.nix
    ./matrix-synapse.nix
    ./mautrix-telegram
    ./matrix-edi.nix
    ./webmumble.nix
    ./letsmeet
  ];

  services.matrix-synapse.isTestInstance = false;

  networking.extraHosts = ''
    127.0.0.1 matrix-dev
  '';
}
