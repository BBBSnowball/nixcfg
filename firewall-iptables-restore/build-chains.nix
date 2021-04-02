{ config, lib, ... }:
with lib;
let
  cfg = config.networking.firewall;

  commonOptions = {
    allowedTCPPorts = null;
    allowedTCPPortRanges = null;
    allowedUDPPorts = null;
    allowedUDPPortRanges = null;
  };
  defaultInterface = { default = mapAttrs (name: value: cfg.${name}) commonOptions; };
  allInterfaces = defaultInterface // cfg.interfaces;

  inherit (config.boot.kernelPackages) kernel;
  kernelHasRPFilter = ((kernel.config.isEnabled or (x: false)) "IP_NF_MATCH_RPFILTER") || (kernel.features.netfilterRPFilter or false);
in
{
  config.networking.firewall.iptables.tables = {
    filter.nixos-fw-accept = {
      header = ''# The "nixos-fw-accept" chain just accepts packets.'';
      rules.default.rules = ''
      -j ACCEPT
      '';
    };
    filter.nixos-fw-refuse.header = ''# The "nixos-fw-refuse" chain rejects or drops packets.'';
    filter.nixos-fw-refuse.rules.default.rules =
      if cfg.rejectPackets then ''
        # Send a reset for existing TCP connections that we've
        # somehow forgotten about.  Send ICMP "port unreachable"
        # for everything else.
        -p tcp ! --syn -j REJECT --reject-with tcp-reset
        -j REJECT
      '' else ''
        # The "nixos-fw-refuse" chain rejects or drops packets.
        -j DROP
      '';

    filter.nixos-fw-log-refuse.header = ''
      # The "nixos-fw-log-refuse" chain performs logging, then
      # jumps to the "nixos-fw-refuse" chain.
      '';
    filter.nixos-fw-log-refuse.rules.default.rules = ''
      ${optionalString cfg.logRefusedConnections ''
        -p tcp --syn -j LOG --log-level info --log-prefix "refused connection: "
      ''}
      ${optionalString (cfg.logRefusedPackets && !cfg.logRefusedUnicastsOnly) ''
        -m pkttype --pkt-type broadcast \
          -j LOG --log-level info --log-prefix "refused broadcast: "
        -m pkttype --pkt-type multicast \
          -j LOG --log-level info --log-prefix "refused multicast: "
      ''}
      -m pkttype ! --pkt-type unicast -j nixos-fw-refuse
      ${optionalString cfg.logRefusedPackets ''
        -j LOG --log-level info --log-prefix "refused packet: "
      ''}
      -j nixos-fw-refuse
      '';

    raw.nixos-fw-rpfilter.enable = kernelHasRPFilter && (cfg.checkReversePath != false);
    raw.nixos-fw-rpfilter.rules.default.rules4 = ''
      # Perform a reverse-path test to refuse spoofers
      # For now, we just drop, as the raw table doesn't have a log-refuse yet
      -m rpfilter --validmark ${optionalString (cfg.checkReversePath == "loose") "--loose"} -j RETURN
  
      # Allows this host to act as a DHCP4 client without first having to use APIPA
      -p udp --sport 67 --dport 68 -j RETURN
  
      # Allows this host to act as a DHCPv4 server
      -s 0.0.0.0 -d 255.255.255.255 -p udp --sport 68 --dport 67 -j RETURN
  
      ${optionalString cfg.logReversePathDrops ''
        -j LOG --log-level info --log-prefix "rpfilter drop: "
      ''}
      -j DROP
      '';
    raw.nixos-fw-rpfilter.rules.default.rules6 = ''
      # Perform a reverse-path test to refuse spoofers
      # For now, we just drop, as the raw table doesn't have a log-refuse yet
      -m rpfilter --validmark ${optionalString (cfg.checkReversePath == "loose") "--loose"} -j RETURN
  
      ${optionalString cfg.logReversePathDrops ''
        -j LOG --log-level info --log-prefix "rpfilter drop: "
      ''}
      -j DROP
      '';
    raw.PREROUTING.rules.rpfilter = {
      enable = kernelHasRPFilter && (cfg.checkReversePath != false);
      order = -50;
      rules = ''-j nixos-fw-rpfilter'';
    };

    filter.INPUT.rules.default.rules = ''-j nixos-fw'';
    filter.nixos-fw.header = ''# The "nixos-fw" chain does the actual work.'';
    filter.nixos-fw.rules = {
      trusted = {
        order = -100;
        rules = ''
          # Accept all traffic on the trusted interfaces.
          ${flip concatMapStrings cfg.trustedInterfaces (iface: ''
            -i ${iface} -j nixos-fw-accept
          '')}
          '';
      };
      established = {
        order = -50;
        rules = ''
          # Accept packets from established or related connections.
          -m conntrack --ctstate ESTABLISHED,RELATED -j nixos-fw-accept
          '';
      };
      default = {
        order = 0;
        rules = ''
          # Accept connections to the allowed TCP ports.
          ${concatStrings (mapAttrsToList (iface: cfg:
            concatMapStrings (port:
              ''
                -p tcp --dport ${toString port} -j nixos-fw-accept ${optionalString (iface != "default") "-i ${iface}"}
              ''
            ) cfg.allowedTCPPorts
          ) allInterfaces)}

          # Accept connections to the allowed TCP port ranges.
          ${concatStrings (mapAttrsToList (iface: cfg:
            concatMapStrings (rangeAttr:
              let range = toString rangeAttr.from + ":" + toString rangeAttr.to; in
              ''
                -p tcp --dport ${range} -j nixos-fw-accept ${optionalString (iface != "default") "-i ${iface}"}
              ''
            ) cfg.allowedTCPPortRanges
          ) allInterfaces)}

          # Accept packets on the allowed UDP ports.
          ${concatStrings (mapAttrsToList (iface: cfg:
            concatMapStrings (port:
              ''
                -p udp --dport ${toString port} -j nixos-fw-accept ${optionalString (iface != "default") "-i ${iface}"}
              ''
            ) cfg.allowedUDPPorts
          ) allInterfaces)}

          # Accept packets on the allowed UDP port ranges.
          ${concatStrings (mapAttrsToList (iface: cfg:
            concatMapStrings (rangeAttr:
              let range = toString rangeAttr.from + ":" + toString rangeAttr.to; in
              ''
                -p udp --dport ${range} -j nixos-fw-accept ${optionalString (iface != "default") "-i ${iface}"}
              ''
            ) cfg.allowedUDPPortRanges
          ) allInterfaces)}

          '';
        rules4 = ''
          # Accept IPv4 multicast.  Not a big security risk since
          # probably nobody is listening anyway.
          #-d 224.0.0.0/4 -j nixos-fw-accept

          # Optionally respond to ICMPv4 pings.
          ${optionalString cfg.allowPing ''
            -p icmp --icmp-type echo-request ${optionalString (cfg.pingLimit != null)
              "-m limit ${cfg.pingLimit} "
            }-j nixos-fw-accept
          ''}
          '';
        rules6 = ''
          ${optionalString config.networking.enableIPv6 ''
            # Accept all ICMPv6 messages except redirects and node
            # information queries (type 139).  See RFC 4890, section
            # 4.4.
            -p icmpv6 --icmpv6-type redirect -j DROP
            -p icmpv6 --icmpv6-type 139 -j DROP
            -p icmpv6 -j nixos-fw-accept

            # Allow this host to act as a DHCPv6 client
            -d fe80::/64 -p udp --dport 546 -j nixos-fw-accept
          ''}
          '';
      };
      refuse = {
        order = 200;
        rules =
          ''
          # Reject/drop everything else.
          -j nixos-fw-log-refuse
          '';
      };
    };
  };
}
