{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.networking.nat;

  dest = if cfg.externalIP == null then "-j MASQUERADE" else "-j SNAT --to-source ${cfg.externalIP}";
in
{
  networking.firewall.iptables.tables.nat = mkIf cfg.enable {
    nixos-nat-pre.rules.default.rules4 = ''
      # We can't match on incoming interface in POSTROUTING, so
      # mark packets coming from the internal interfaces.
      ${concatMapStrings (iface: ''
        -i '${iface}' -j MARK --set-mark 1
      '') cfg.internalInterfaces}

      # NAT from external ports to internal ports.
      ${concatMapStrings (fwd: ''
        -i ${toString cfg.externalInterface} -p ${fwd.proto} \
          --dport ${builtins.toString fwd.sourcePort} \
          -j DNAT --to-destination ${fwd.destination}
  
        ${concatMapStrings (loopbackip:
          let
            m                = builtins.match "([0-9.]+):([0-9-]+)" fwd.destination;
            destinationIP    = if (m == null) then throw "bad ip:ports `${fwd.destination}'" else elemAt m 0;
            destinationPorts = if (m == null) then throw "bad ip:ports `${fwd.destination}'" else builtins.replaceStrings ["-"] [":"] (elemAt m 1);
          in ''
            # Allow connections to ${loopbackip}:${toString fwd.sourcePort} from other hosts behind NAT
            -d ${loopbackip} -p ${fwd.proto} \
              --dport ${builtins.toString fwd.sourcePort} \
              -j DNAT --to-destination ${fwd.destination}
          '') fwd.loopbackIPs}
      '') cfg.forwardPorts}
  
      ${optionalString (cfg.dmzHost != null) ''
        -i ${toString cfg.externalInterface} -j DNAT \
          --to-destination ${cfg.dmzHost}
      ''}
    '';

    nixos-nat-post.rules.default.rules4 = ''
      # NAT the marked packets.
      ${optionalString (cfg.internalInterfaces != []) ''
        -m mark --mark 1 \
          ${optionalString (cfg.externalInterface != null) "-o ${cfg.externalInterface}"} ${dest}
      ''}

      # NAT packets coming from the internal IPs.
      ${concatMapStrings (range: ''
        -s '${range}' ${optionalString (cfg.externalInterface != null) "-o ${cfg.externalInterface}"} ${dest}
      '') cfg.internalIPs}
  
      # NAT from external ports to internal ports.
      ${concatMapStrings (fwd: ''
        ${concatMapStrings (loopbackip:
          let
            m                = builtins.match "([0-9.]+):([0-9-]+)" fwd.destination;
            destinationIP    = if (m == null) then throw "bad ip:ports `${fwd.destination}'" else elemAt m 0;
            destinationPorts = if (m == null) then throw "bad ip:ports `${fwd.destination}'" else builtins.replaceStrings ["-"] [":"] (elemAt m 1);
          in ''
            # second half of hairpinning (first half is in PREROUTING)
            -d ${destinationIP} -p ${fwd.proto} \
              --dport ${destinationPorts} \
              -j SNAT --to-source ${loopbackip}
          '') fwd.loopbackIPs}
      '') cfg.forwardPorts}
      '';

    nixos-nat-out.rules.default.rules4 = ''
      # NAT from external ports to internal ports.
      ${concatMapStrings (fwd: ''
        ${concatMapStrings (loopbackip:
          let
            m                = builtins.match "([0-9.]+):([0-9-]+)" fwd.destination;
            destinationIP    = if (m == null) then throw "bad ip:ports `${fwd.destination}'" else elemAt m 0;
            destinationPorts = if (m == null) then throw "bad ip:ports `${fwd.destination}'" else builtins.replaceStrings ["-"] [":"] (elemAt m 1);
          in ''
            # Allow connections to ${loopbackip}:${toString fwd.sourcePort} from the host itself
            -d ${loopbackip} -p ${fwd.proto} \
              --dport ${builtins.toString fwd.sourcePort} \
              -j DNAT --to-destination ${fwd.destination}
          '') fwd.loopbackIPs}
      '') cfg.forwardPorts}
    '';

    # Append our chains to the nat tables
    PREROUTING.rules.nat.rules4 = ''-j nixos-nat-pre'';
    POSTROUTING.rules.nat.rules4 = ''-j nixos-nat-post'';
    OUTPUT.rules.nat.rules4 = ''-j nixos-nat-out'';
  };
}
