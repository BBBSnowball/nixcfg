# extra-container create container-matrix-dev.nix --update-changed
{ config, lib, pkgs, ... }:

with lib;

{
  containers.matrix-dev = {
    privateNetwork = false;
    bindMounts.nixos-secret = {
      hostPath   = "/etc/nixos/secret/matrix-synapse-dev";
      mountPoint = "/etc/nixos/secret/matrix-synapse-dev";
    };
    bindMounts.nixChannel = {
      hostPath   = "/nix/var/nix/profiles/per-user/root/channels/nixos";
      mountPoint = "/nix/var/nix/profiles/per-user/root/channels/nixos";
    };
    config = {
      boot.isContainer = true;
      networking.hostName = mkDefault "matrix-dev";
      networking.useDHCP = false;
      system.stateVersion = "19.03";

      imports = [
        ./matrix-synapse-dev.nix
      ];

      environment.systemPackages = with pkgs; [
        wget htop tmux byobu git vim tig
        openssl
        (python3.withPackages (p: matrix-synapse.propagatedBuildInputs ++ (with p; [ mock parameterized ])))
      ];

      # don't start Synapse on boot
      systemd.services.matrix-synapse.unitConfig.ConditionPathExists = "/nope";

      users.users.test = {
        isNormalUser = true;
      };

      programs.vim.defaultEditor = true;
      environment.etc.vimrc.text = ''
        imap fd <Esc>
      '';
    };
  };
}
