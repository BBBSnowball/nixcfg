{ config, pkgs, lib, ... }:
let
  sections = [ "ALL" "ESTABLISHED" "RELATED" "INVALID" "UNTRACKED" "NEW" ];

  common = {
    zones = ''
      #ZONE     TYPE       OPTIONS       IN OPTIONS         OUT OPTIONS

      fw	firewall
      net       ip
      modem     ip
      loc       ip
      tinc      ip
    '';

    interfaces = ''
      ?FORMAT 2
      #ZONE   INTERFACE       OPTIONS

      net     NET_IF          tcpflags,nosmurfs,routefilter,logmartians,sourceroute=0,physical=ppp0,arp_filter=1
      modem   MODEM_IF        tcpflags,nosmurfs,routefilter,logmartians,sourceroute=0,physical=enp4s0,arp_filter=1
      loc     LOC_IF          tcpflags,nosmurfs,routefilter,logmartians,physical=br0,routeback,arp_filter=1,dhcp
      tinc    TINC_IF         tcpflags,nosmurfs,routefilter,logmartians,physical=tinc.bbbsnowbal,routeback,arp_filter=1,dhcp
    '';

    policy = ''
      #SOURCE DEST            POLICY          LOGLEVEL        RATE    CONNLIMIT

      loc     net             ACCEPT
      $FW     net,loc,tinc    ACCEPT
      net     all             DROP            $LOG_LEVEL      $LOGLIMIT
      all     all             REJECT          $LOG_LEVEL      $LOGLIMIT
    '';

    stoppedrules = ''
      #ACTION      SOURCE       DEST         PROTO       DEST        SOURCE

      ACCEPT       LOC_IF       -
      ACCEPT       -            LOC_IF
      ACCEPT       LOC_IF       $FW          tcp         22
    '';

    rules = with builtins; let
      rulesWithName = lib.attrsets.mapAttrsToList (name: value: { inherit name; } // value) config.services.shorewall.rules;
      bySection = lib.lists.groupBy (x: x.section) rulesWithName;
      dropTrailingNulls = xs:
        let xs2 = dropTrailingNulls (tail xs); in
        if xs == []
          then xs
          else if head xs == null && xs2 == []
            then []
            else[ (head xs) ] ++ xs2;
      replaceNulls = map (x: if isNull x then "-" else x);
      portsToString = p:
        if isList p
          then lib.strings.concatMapStringsSep "," toString p
          else toString p;
      ruleToLines = rule:
      if isNull rule.raw
      then [
        "# ${rule.name}"
        (replaceNulls (dropTrailingNulls [
          "${if rule.enable then "" else "#"}${rule.action}"
          (if isNull rule.source then config.services.shorewall.defaultSource else rule.source)
          (if isNull rule.dest   then config.services.shorewall.defaultDest   else rule.dest)
          rule.proto
          (portsToString rule.destPort)
          (portsToString rule.sourcePort)
          (if rule.extraFields == "" then null else rule.extraFields)
        ])) ]
      else if isList rule.raw && rule.raw != [] && isList (head rule.raw)
        then rule.raw
        else [ rule.raw ];
      compareRules = a: b: a.order < b.order || a.order == b.order && a.name < b.name;
      sectionToLines = name: rules: [ "" "?SECTION ${name}" ] ++ concatMap ruleToLines (lib.lists.sort compareRules rules);
      lines = concatMap (name: sectionToLines name (bySection.${name} or [])) sections;
      max = a: b: if a >= b then a else b;
      mapMax = xs: ys:
        if xs == [] then ys
        else if ys == [] then xs
        else [ (max (head xs) (head ys)) ] ++ (mapMax (tail xs) (tail ys));
      fieldLengths =
        let rawLengths = lib.lists.foldl' (a: b: if isList b then mapMax a (map stringLength b) else a) [0] lines; in
        # never pad the last field
        (lib.lists.init rawLengths) ++ [ 0 ];
      padding = n: if n > 0 then " " + (padding (n - 1)) else "";
      padField = width: value: if stringLength value < width
        then value + padding (width - (stringLength value))
        else value;
      lineToString = line: if isList line then lib.strings.concatStringsSep  "    " (lib.lists.zipListsWith padField fieldLengths line) else line;
      rules = lib.strings.concatMapStringsSep "\n" lineToString lines;
    in ''
      #ACTION           SOURCE          DEST            PROTO   DPORT     SPORT    ORIGDEST    RATELIMIT    USER    MARK    CONNLIMIT    TIME    HEADERS    SWITCH    HELPER

      ?SECTION ALL
      ?SECTION ESTABLISHED
      ?SECTION RELATED
      ?SECTION INVALID
      ?SECTION UNTRACKED
      ?SECTION NEW

      Invalid(DROP)     net             all             tcp
      DNS(ACCEPT)       $FW             net
      SSH(ACCEPT)       loc             $FW
      Ping(ACCEPT)      loc             $FW
      Ping(ACCEPT)      net             $FW
      ACCEPT            $FW             loc             icmp
      REJECT            all:10.0.0.0/8,\
                            169.254.0.0/16,\
                            172.16.0.0/12,\
                            192.168.0.0/16\
                                        net
      REJECT            all             net:10.0.0.0/8,\
                                            169.254.0.0/16,\
                                            172.16.0.0/12,\
                                            192.168.0.0/16
      ACCEPT            $FW             net             icmp

      ${builtins.toJSON config.services.shorewall.rules}
      ${builtins.toJSON rulesWithName}
      {builtins.toJSON bySection}

      ${rules}
    '';
  };

  packages = with pkgs; [
    coreutils shorewall iptables-nftables-compat iproute ipset inetutils gnugrep gnused
    #iptables ebtables
  ];

  mainConfigFile = ''
    STARTUP_ENABLED=Yes
    VERBOSITY=1

    LOG_VERBOSITY=2
    LOG_ZONE=Both
    LOGFILE=systemd
    STARTUP_LOG=/var/log/shorewall-init.log
    LOGFORMAT="%s %s "
    LOGTAGONLY=No
    LOGLIMIT="s:1/sec:10"

    LOG_LEVEL="info"
    MACLIST_LOG_LEVEL="$LOG_LEVEL"
    RPFILTER_LOG_LEVEL="$LOG_LEVEL"
    SFILTER_LOG_LEVEL="$LOG_LEVEL"
    SMURF_LOG_LEVEL="$LOG_LEVEL"
    TCP_FLAGS_LOG_LEVEL="$LOG_LEVEL"

    RESTOREFILE=restore

    ###############################################################################
    #		D E F A U L T   A C T I O N S / M A C R O S
    ###############################################################################

    ACCEPT_DEFAULT="none"
    BLACKLIST_DEFAULT="Broadcast(DROP),Multicast(DROP),dropNotSyn:$LOG_LEVEL,dropInvalid:$LOG_LEVEL,DropDNSrep:$LOG_LEVEL"
    DROP_DEFAULT="Broadcast(DROP),Multicast(DROP)"
    NFQUEUE_DEFAULT="none"
    QUEUE_DEFAULT="none"
    REJECT_DEFAULT="Broadcast(DROP),Multicast(DROP)"

    ###############################################################################
    #			F I R E W A L L	  O P T I O N S
    ###############################################################################

    ADD_IP_ALIASES=No
    ADMINISABSENTMINDED=Yes
    AUTOMAKE=Yes
    BALANCE_PROVIDERS=No
    BLACKLIST="NEW,INVALID,UNTRACKED"
    CLAMPMSS=Yes
    DETECT_DNAT_IPADDRS=No
    EXPAND_POLICIES=Yes
    IP_FORWARDING=On
    MANGLE_ENABLED=Yes
    OPTIMIZE=All
    RESTART=restart
    TRACK_PROVIDERS=Yes
    TRACK_RULES=File
    USE_NFLOG_SIZE=Yes
    WORKAROUNDS=No

    PERL=${pkgs.perl}/bin/perl
    #PATH=${lib.strings.concatMapStringsSep ":" (p: "${p}/bin") packages}
    PATH=${lib.strings.makeBinPath packages}
    PAGER=${pkgs.less}/bin/less -R
  '';
in
{
  options = {
    services.shorewall = with lib.types; {
      rules = lib.mkOption {
        type = attrsOf (submodule {
          options = {
            enable = lib.mkOption {
              type = bool;
              default = true;
            };
            order = lib.mkOption {
              type = int;
              default = 10;
            };
            section = lib.mkOption {
              type = enum sections;
              default = "NEW";
            };
            action = lib.mkOption {
              type = str;
              default = "ACCEPT";
            };
            source = lib.mkOption {
              type = nullOr str;
              default = null;
            };
            dest = lib.mkOption {
              type = nullOr str;
              default = null;
            };
            proto = lib.mkOption {
              type = nullOr str;
              default = null;
            };
            destPort = lib.mkOption {
              type = nullOr (oneOf [str port (listOf port)]);
              default = null;
            };
            sourcePort = lib.mkOption {
              type = nullOr (oneOf [str port (listOf port)]);
              default = null;
            };
            extraFields = lib.mkOption {
              type = str;
              default = "";
            };
            raw = lib.mkOption {
              type = nullOr (oneOf [ str (listOf str) (listOf (listOf str)) ]);
              description = "raw text of rule; replaces all other fields";
              default = null;
            };
          };
        });
        default     = {};
        description = ''
          This defines Shorewall rules.
        '';
      };

      defaultSource = lib.mkOption {
        type = nullOr str;
        description = "Default source for rules. This should usually be the internal network if you have many rules opening ports to that network.";
        default = "loc";
      };
      defaultDest = lib.mkOption {
        type = nullOr str;
        description = "Default destination for rules. This should usually be the firewall if you have many rules opening ports on the firewall.";
        default = "$FW";
      };
    };
  };

  config = {
    services.shorewall.enable = true;
    #services.shorewall6.enable = true;
    services.shorewall.configs = common // {
      "shorewall.conf" = mainConfigFile + ''
        LOG_MARTIANS=Yes
      '';
      snat = ''
        #ACTION        SOURCE               DEST        PROTO    PORT    IPSEC    MARK    USER    SWITCH    ORIGDEST    PROBABILITY
        MASQUERADE     192.168.89.0/24      NET_IF
      '';
    };
    services.shorewall6.configs = common // {
      "shorewall6.conf" = mainConfigFile;
    };
    systemd.services.shorewall.path = packages;

    #environment.systemPackages = packages;

    environment.etc.nixos-firewall.text = ''
      TCP: ${toString config.networking.firewall.allowedTCPPorts} ${toString config.networking.firewall.allowedTCPPortRanges}
      UDP: ${toString config.networking.firewall.allowedUDPPorts} ${toString config.networking.firewall.allowedUDPPortRanges}
      per interface: ${builtins.toJSON config.networking.firewall.interfaces}
    '';
  };
}
