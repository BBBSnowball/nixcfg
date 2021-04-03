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

  normalNatUpstream = import (modulesPath + "/services/networking/nat.nix") { inherit config pkgs lib; };
  normalNatLocalCopy = import ./original/nat.nix { inherit config pkgs lib; };
  upstreamNatChanged = compare normalNatUpstream.config normalNatLocalCopy.config;

  assertions =
    [ { assertion = isNull upstreamFirewallChanged;
        message = "The upstream firewall module in NixOS has changed and this does affect your config so the iptables-restore module must be adapted: ${upstreamFirewallChanged}";
      }
      { assertion = isNull upstreamNatChanged;
        message = "The upstream firewall module in NixOS has changed and this does affect your config so the iptables-restore module must be adapted: ${upstreamNatChanged}";
      }
    ];

  compareFile = a: b: { condition = readFile a != readFile b; message = "Upstream firewall module is different: see ${a} and ${b}."; };
  warnings =
    [ (compareFile (modulesPath + "/services/networking/firewall.nix") ./original/firewall.nix)
      (compareFile (modulesPath + "/services/networking/helpers.nix") ./original/helpers.nix)
      (compareFile (modulesPath + "/services/networking/nat.nix") ./original/nat.nix)
  ];

  mkIfForAttrs = cond: attrs: value: lists.fold (attrPath: value: mkIfForAttrs' cond (strings.splitString "." attrPath) value) value attrs;
  mkIfForAttrs' = cond: attrPath: value: let name' = head attrPath; name = if strings.hasPrefix "?" name' then substring 1 100 name' else name'; in
    if attrPath == [] then mkIf cond value
    else if value ? _type && value._type == "merge" then value // { contents = map (mkIfForAttrs' cond attrPath) value.contents; }
    else if value ? _type && value._type == "if" then value // { content = mkIfForAttrs' cond attrPath value.content; }
    else if value ? ${name} then value // { ${name} = mkIfForAttrs' cond (tail attrPath) value.${name}; }
    else if strings.hasPrefix "?" name' then value
    else throw "not found: ${toString attrPath}, ${name}, ${toString (attrNames value)}";
in
{
  disabledModules = [
    "services/networking/firewall.nix"
    "services/networking/nat.nix"
  ];

  imports = [
    ./options.nix
    ./build-chains.nix
    ./build-scripts.nix
    { inherit (normalFirewallUpstream) options; }
    { inherit (normalNatUpstream) options; }
  ];

  config = mkMerge [
    (mkIfForAttrs (!cfg.enable) [ "systemd.services.firewall.serviceConfig.ExecStart" "systemd.services.firewall.serviceConfig.ExecReload" ] normalFirewallUpstream.config)
    (mkIfForAttrs (!cfg.enable) [ "networking.firewall.extraCommands" "networking.firewall.?extraStopCommands" ] normalNatUpstream.config)
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
