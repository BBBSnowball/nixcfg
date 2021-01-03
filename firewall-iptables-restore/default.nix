{ config, pkgs, lib, modulesPath, ... }:
with lib;
with builtins;
with import ./lib.nix { inherit pkgs lib; };
let
  cfg = config.networking.firewall.iptables-restore;
  cfg-fw = config.networking.firewall;

  normalFirewallUpstream = import (modulesPath + "/services/networking/firewall.nix") { inherit config pkgs lib; };
  normalFirewallLocalCopy = import ./original/firewall.nix { inherit config pkgs lib; };
  upstreamFirewallChanged = compare normalFirewallUpstream.config normalFirewallLocalCopy.config;

  assertions =
    [ { assertion = isNull upstreamFirewallChanged;
        message = "The upstream firewall module in NixOS has changed and this does affect your config so the iptables-restore module must be adapted: ${upstreamFirewallChanged}";
      }
    ];

  compareFile = a: b: { condition = readFile a != readFile b; message = "Upstream firewall module is different: see ${a} and ${b}."; };
  warnings =
    [ (compareFile (modulesPath + "/services/networking/firewall.nix") ./original/firewall.nix)
      (compareFile (modulesPath + "/services/networking/helpers.nix") ./original/helpers.nix) ];

  mkIfForAttrs = cond: attrs: value: lists.fold (attrPath: value: mkIfForAttrs' cond (strings.splitString "." attrPath) value) value attrs;
  mkIfForAttrs' = cond: attrPath: value: let name = head attrPath; in
    if attrPath == [] then mkIf cond value
    else if value ? ${name} then value // { ${name} = mkIfForAttrs' cond (tail attrPath) value.${name}; }
    else throw "not found: ${toString attrPath}, ${name}, ${toString (attrNames value)}";
in
{
  disabledModules = [ "services/networking/firewall.nix" ];

  imports = [
    ./options.nix
    ./build-chains.nix
    ./build-scripts.nix
  ];

  options = normalFirewallUpstream.options;

  config = mkMerge [
    (mkIfForAttrs (!cfg.enable) [ "systemd.services.firewall.serviceConfig.ExecStart" "systemd.services.firewall.serviceConfig.ExecReload" ] normalFirewallUpstream.config.content)
    (mkIf cfg.enable ({
      assertions = assertions;
  
      warnings = filter (x: ! isNull x) (map (x: if x.condition then x.message else null) warnings);
  
      #FIXME This will always override way too much.
      systemd.services.firewall = {
        environment.IP4TABLES_SCRIPT = cfg.script-ipv4;
        environment.IP6TABLES_SCRIPT = cfg.script-ipv6;
  
        script = ''
          ${cfg-fw.package}/bin/iptables-restore $IP4TABLES_SCRIPT
          ${cfg-fw.package}/bin/ip6tables-restore $IP6TABLES_SCRIPT
          ${cfg-fw.extraCommands}
        '';
        reload = ''
          #TODO is this right?
          ${cfg-fw.package}/bin/iptables-restore $IP4TABLES_SCRIPT
          ${cfg-fw.package}/bin/ip6tables-restore $IP6TABLES_SCRIPT
          ${cfg-fw.extraCommands}
        '';
        #TODO should we replace ExecStop, as well?
      };
    }))
  ];
}
