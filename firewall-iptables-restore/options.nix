{ lib, ... }:
with lib;
let
  chainOptions.options = {
    enable = mkOption {
      type = types.bool;
      default = true;
    };
    policy = mkOption {
      type = types.nullOr (types.enum [ "ACCEPT" "DROP" ]);
      default = null;
      example = "DROP";
      description = ''default action, only valid for built-in chains'';
    };
    create = mkOption {
      type = types.nullOr types.bool;
      default = null;
      example = true;
      description = ''
        If true, create the chain. The default is to create any chains that start with a low-case letter.
      '';
    };
    header = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Extra lines that are inserted before the chain is created. This should usually be a comment
        that describes the purpose of the chain.
      '';
    };
    rules = mkOption {
      type = types.attrsOf (types.submodule labelType);
      default = {};
      example = {
        early = { order = -100; rules4 = ''-i ens3 --src 127.0.0.0/8 -j DROP''; };
        default.rules = ''
          -i ens3 -p tcp --dport 443 -j ACCEPT
        '';
        last = {
          order = 100;
          rules = ''
            -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j LOG --log-prefix "refused connection: " --log-level 6
            -j REJECT
          '';
        };
      };
      description = ''
        Rules for an iptables chain.

        The rules are associated to labels that are sorted by their order.
        Iptables doesn't have a concept of labels. This is only for internal
        bookkeeping and getting the order right.
      '';
    };
  };
  labelType.options = {
    enable = mkOption {
      type = types.bool;
      default = true;
    };
    order = mkOption {
      type = types.int;
      default = 0;
      description = ''
        Labels are sorted by order, with smaller values first. The default value is 0 so use negative values for early rules.
      '';
    };
    rules = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Rules and comments, one per line. Use iptables-restore syntax. Applied for iptables as well as ip6tables.
      '';
    };
    rules4 = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Rules and comments, only applied of iptables (IPv4).
      '';
    };
    rules6 = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Rules and comments, only applied of ip6tables (IPv6).
      '';
    };
  };
in
{
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
        description = ''
          Script for iptables-restore. This is usually generated from networking.firewall.iptables.tables.
        '';
      };
  
      script-ipv6 = mkOption {
        type = types.path;
        description = ''
          Script for ip6tables-restore. This is usually generated from networking.firewall.iptables.tables.
        '';
      };
    };

    iptables.tables = mkOption {
      type = types.attrsOf (types.attrsOf (types.submodule chainOptions));
      default = { filter = {}; };
      example = {
        filter.INPUT.policy = "DROP";
        filter.INPUT.rules.default.rules = ''
          -i ens3 -p tcp --dport 443 -j ACCEPT
        '';
        filter.FORWARD.rules.default.rules = ''
          -i ens3 -o ens4 -m state --state RELATED,ESTABLISHED -j ACCEPT
          -i ens4 -o ens3 -j ACCEPT
        '';
        nat.POSTROUTING.rules.default.rules = ''
          -o ens3 -j MASQUERADE
        '';
      };
      description = ''
        Nested attrset of tables and chains.

        Table can be one of: filter, nat, mangle, raw, security
        Chain can be one of the built-in ones (depends on the table) or a user-defined one.
      '';
    };
  };
}
