{ config, pkgs, lib, ... }:
{
  services.iperf3 = {
    enable = true;
    openFirewall = true;
  };
  #systemd.services.iperf3-udp = let tcp = config.systemd.services.iperf3; in tcp // {
  #  serviceConfig = tcp.serviceConfig // {
  #    ExecStart = tcp.serviceConfig.ExecStart + " --udp";
  #  };
  #};
  #networking.firewall.allowedUDPPorts = [ config.systemd.services.iperf3.port ];

  # copied from https://github.com/NixOS/nixpkgs/blob/nixos-22.05/nixos/modules/services/networking/iperf3.nix  
  systemd.services.iperf3-udp = let cfg = config.services.iperf3; in with lib; {
    description = "iperf3 daemon";
    unitConfig.Documentation = "man:iperf3(1) https://iperf.fr/iperf-doc.php";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 2;
      DynamicUser = true;
      PrivateDevices = true;
      CapabilityBoundingSet = "";
      NoNewPrivileges = true;
      ExecStart = ''
        ${pkgs.iperf3}/bin/iperf \
          --server \
          --port ${toString cfg.port} \
          ${optionalString (cfg.affinity != null) "--affinity ${toString cfg.affinity}"} \
          ${optionalString (cfg.bind != null) "--bind ${cfg.bind}"} \
          ${optionalString (cfg.rsaPrivateKey != null) "--rsa-private-key-path ${cfg.rsaPrivateKey}"} \
          ${optionalString (cfg.authorizedUsersFile != null) "--authorized-users-path ${cfg.authorizedUsersFile}"} \
          ${optionalString cfg.verbose "--verbose"} \
          ${optionalString cfg.debug "--debug"} \
          ${optionalString cfg.forceFlush "--forceflush"} \
          ${escapeShellArgs cfg.extraFlags} \
          --udp
      '';
    };
  };

  networking.firewall.allowedUDPPorts = [
    config.services.iperf3.port
  ];

  # static build for mips (for running on old Omada APs):
  # ##with openssl, huge: nix-build -E '(import <nixpkgs> { crossSystem = { config = "mips-unknown-linux-gnu"; }; config.allowUnsupportedSystem = true; }).pkgsStatic.iperf3'
  # nix-build -E '((import <nixpkgs> { crossSystem = { config = "mips-unknown-linux-gnu"; }; config.allowUnsupportedSystem = true; }).pkgsStatic.iperf3.override { openssl = null; }).overrideAttrs (old: { configureFlags = []; })'
  # ssh user@ap 'cat >/tmp/logdump/iperf3' <result/bin/iperf3
  # ssh user@ ap 'cd /tmp/logdump && TEMP=. TMPDIR=. ./iperf3 -c target'  # tested on TP-Link EAP115
  # (server mode doesn't work unless we find an open port in the firewall)
}
