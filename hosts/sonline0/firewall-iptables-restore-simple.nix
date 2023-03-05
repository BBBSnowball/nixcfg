{ config, pkgs, lib, modulesPath, ... }:
with lib;
with builtins;
let
  cfg = config.networking.firewall.iptables-restore;
  cfg-fw = config.networking.firewall;

  firewall-update = pkgs.runCommand "firewall-update" {
    inherit (pkgs) runtimeShell;
    inherit (pkgs.stdenv) shellDryRun;
    path = lib.makeBinPath (with pkgs; [ cfg-fw.package ruby coreutils gnused bash ]);
    script_ipv4 = cfg.script-ipv4;
    script_ipv6 = cfg.script-ipv6;
  } ''
    mkdir -p $out/bin
    substitute ${./firewall-update.sh} $out/bin/firewall-update \
      --subst-var runtimeShell \
      --subst-var path \
      --subst-var script_ipv4 \
      --subst-var script_ipv6
    chmod +x $out/bin/firewall-update
    $shellDryRun $out/bin/firewall-update
  '';
in
{
  disabledModules = [
    #"services/networking/firewall.nix"
    #"services/networking/nat.nix"
  ];

  imports = [
  ];

  options.networking.firewall = {
    iptables-restore = {
      enable = mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = ''
          Use iptables-restore to setup the firewall.
        '';
      };

      script-ipv4 = mkOption {
        type = types.path;
        default = "/etc/iptables/rules.v4";
        description = ''
          Script for iptables-restore.
        '';
      };

      script-ipv6 = mkOption {
        type = types.path;
        default = "/etc/iptables/rules.v6";
        description = ''
          Script for ip6tables-restore.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.enable = false;

    systemd.services.firewall = {
      description = "Firewall";
      wantedBy = [ "sysinit.target" ];
      wants = [ "network-pre.target" ];
      before = [ "network-pre.target" ];
      after = [ "systemd-modules-load.service" ];

      path = [ cfg-fw.package ] ++ cfg-fw.extraPackages;

      unitConfig.ConditionCapability = "CAP_NET_ADMIN";
      unitConfig.DefaultDependencies = false;

      reloadIfChanged = true;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      environment.IP4TABLES_SCRIPT = cfg.script-ipv4;
      environment.IP6TABLES_SCRIPT = cfg.script-ipv6;

      script = ''
        ${cfg-fw.package}/bin/iptables-restore $IP4TABLES_SCRIPT
        ${cfg-fw.package}/bin/ip6tables-restore $IP6TABLES_SCRIPT
        ${cfg-fw.extraCommands}
      '';
      reload = ''
        ${cfg-fw.package}/bin/iptables-restore $IP4TABLES_SCRIPT
        ${cfg-fw.package}/bin/ip6tables-restore $IP6TABLES_SCRIPT
        ${cfg-fw.extraCommands}
      '';
      #TODO should we replace ExecStop, as well?
    };

    environment.systemPackages = [ cfg-fw.package firewall-update ];
  };
}
