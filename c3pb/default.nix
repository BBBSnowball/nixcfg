{ pkgs, config, lib, ... }:
{
  imports = [
    ./autossh.nix
    ./mumbleweb.nix
    ./dinge-info.nix
    ./matrix-synapse.nix
    ./mautrix-telegram
    ./matrix-edi.nix
  ];
}
