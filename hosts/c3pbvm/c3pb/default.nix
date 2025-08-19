{ pkgs, config, lib, withFlakeInputs, ... }:
{
  imports = [
    (withFlakeInputs ./autossh.nix)
    #(withFlakeInputs ./mumbleweb.nix)
    (withFlakeInputs ./dinge-info.nix)
    (withFlakeInputs ./matrix-synapse.nix)
    #(withFlakeInputs ./mautrix-telegram) # moved to revreso
    #(withFlakeInputs ./matrix-edi.nix)   # replaced by newer bot
    (withFlakeInputs ./element-web.nix)
    (withFlakeInputs ./webmumble.nix)
    (withFlakeInputs ./letsmeet)
  ];

  services.matrix-synapse.isTestInstance = false;

  networking.extraHosts = ''
    127.0.0.1 matrix-dev
  '';
}
