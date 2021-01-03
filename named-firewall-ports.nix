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
    networking.firewall.allowedPortsInterface = mkOption {
      type = types.str;
      default = "";
      example = "eth0";
      description = "open ports in allowedPorts on specific interface; use \"\" for all interfaces";
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
    iface = config.networking.firewall.allowedPortsInterface;
  #NOTE Useful functions for debugging: abort, builtins.toXML, builtins.toJSON, builtins.trace
  in {
    #NOTE We have to "tell" Nix which attributes we might be setting before we can use any config options.
    #     Otherwise, we will end up with infinite recursion.
    networking.firewall.allowedTCPPorts       = if iface == "" then firewallOptions.allowedTCPPorts      else {};
    networking.firewall.allowedUDPPorts       = if iface == "" then firewallOptions.allowedUDPPorts      else {};
    networking.firewall.allowedTCPPortRanges  = if iface == "" then firewallOptions.allowedTCPPortRanges else {};
    networking.firewall.allowedUDPPortRanges  = if iface == "" then firewallOptions.allowedUDPPortRanges else {};
    networking.firewall.interfaces."${iface}" = if iface != "" then firewallOptions                      else {};
  };
}
