{ config, pkgs, lib, ... }:
with lib;
let
  portType = types.addCheck (types.submodule {
    options = {
      port = mkOption { type = types.nullOr types.port; default = null; };
      from = mkOption { type = types.nullOr types.port; default = null; };
      to   = mkOption { type = types.nullOr types.port; default = null; };
      type = mkOption { type = types.enum [ "tcp" "udp" ]; };
    };
  }) (x: (x.port != null && x.from == null && x.to == null) || (x.port == null && x.from != null && x.to != null));
  portTypeOrPort = types.coercedTo types.port (port: { inherit port; type = "tcp"; }) portType;
  allowedPortsType = types.attrsOf portTypeOrPort;
in {
  options = {
    networking.firewall.allowedPortsInterfaces = mkOption {
      type = with types; listOf str;
      default = [];
      example = [ "eth0" ];
      description = "open ports in allowedPorts on specific interfaces; use [] for all interfaces";
    };
    networking.firewall.allowedPorts = mkOption {
      type = allowedPortsType;
      default = {};
      example = { ssh = 22; dns = { port = 53; type = "udp"; }; };
      description = "an attr-valued variant of allowedTcpPorts et. al. (so values can be set in different places more easily)";
    };
  };

  config = let
    filterType = type: attrs: filter (x: x.type == type) (attrValues attrs);
    extractPorts  = portAttrs: map (x: x.port)                   (filter (x: x.port != null) portAttrs);
    extractRanges = portAttrs: map (x: { inherit (x) from to; }) (filter (x: x.from != null) portAttrs);
    duplicatePorts = ports: let
      normalizedPorts = lib.attrsets.mapAttrsToList (name: value: with value; {
        inherit name type;
        from = (if from != null then from else port);
        to   = (if from != null then to   else port);
      }) ports;
      sorted = builtins.sort (a: b: (lib.lists.compareLists lib.trivial.compare [a.type a.from a.to] [b.type b.from b.to]) < 0) normalizedPorts;
      check = a: b: optional (a.type == b.type && a.to >= b.from) { type = a.type; a = a.name; b = b.name; port = b.from; };
      duplicates = builtins.concatLists (lib.lists.zipListsWith check sorted (lib.lists.drop 1 sorted));
    in duplicates;
    check = x:
      let dup = duplicatePorts config.networking.firewall.allowedPorts;
        in assert lib.asserts.assertMsg (dup == []) ("duplicate ports: " + builtins.toJSON dup);
      x;
    firewallOptions = check {
      allowedTCPPorts      = extractPorts  (filterType "tcp" config.networking.firewall.allowedPorts);
      allowedUDPPorts      = extractPorts  (filterType "udp" config.networking.firewall.allowedPorts);
      allowedTCPPortRanges = extractRanges (filterType "tcp" config.networking.firewall.allowedPorts);
      allowedUDPPortRanges = extractRanges (filterType "udp" config.networking.firewall.allowedPorts);
    };
    allInterfaces = length config.networking.firewall.allowedPortsInterfaces == 0;
    perInterface = listToAttrs (map (iface: nameValuePair iface firewallOptions) config.networking.firewall.allowedPortsInterfaces);
  #NOTE Useful functions for debugging: abort, builtins.toXML, builtins.toJSON, builtins.trace
  in mkMerge [
    (mkIf allInterfaces {
      #NOTE We have to "tell" Nix which attributes we might be setting before we can use any config options.
      #     Otherwise, we will end up with infinite recursion.
      networking.firewall = {
        inherit (firewallOptions)
          allowedTCPPorts
          allowedUDPPorts
          allowedTCPPortRanges
          allowedUDPPortRanges;
      };
    })
    { networking.firewall.interfaces = perInterface; }
  ];
}
