{ config, pkgs, lib, ... }:
let
  sections = [ "ALL" "ESTABLISHED" "RELATED" "INVALID" "UNTRACKED" "NEW" ];

  common = ipv6: {
    zones = ''
      #ZONE     TYPE       OPTIONS       IN OPTIONS         OUT OPTIONS

      fw	firewall
      net       ip
      modem     ip
      loc       ip
      tinc      ip
    '';

    interfaces = let
      myDefaultOptions = if ipv6
        then "tcpflags,nosmurfs"
        else "tcpflags,nosmurfs,routefilter,logmartians,arp_filter=1";
    in ''
      ?FORMAT 2
      #ZONE   INTERFACE       OPTIONS

      net     NET_IF          ${myDefaultOptions},sourceroute=0,physical=pppoe-wan
      modem   MODEM_IF        ${myDefaultOptions},sourceroute=0,physical=upstream-7
      loc     LOC_IF          ${myDefaultOptions},physical=br0,routeback,dhcp
      tinc    TINC_IF         ${myDefaultOptions},physical=tinc.bbbsnowbal,dhcp
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
  };

  getRules = acceptRule:
    with builtins; let
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
        if isNull p then null
        else if isList p
          then lib.strings.concatMapStringsSep "," toString p
          else toString p;

      commentOne = line:
        if line == "" || line == [] then line
        else if isList line then ("#" + (head line)) ++ (tail line)
        else "#" + line;
      commentIfNotEnabled = enabled: line: if enabled then line else commentOne line;
      traceId = x: trace x x;
      traceIdJson = x: trace (toJSON x) x;
      singleRuleToLine = rule:
        (commentIfNotEnabled rule.enable (replaceNulls (dropTrailingNulls (
        if ! (isNull rule.raw)
        then rule.raw
        else [
          rule.action
          (if isNull rule.source then config.services.shorewall.defaultSource else rule.source)
          (if isNull rule.dest   then config.services.shorewall.defaultDest   else rule.dest)
          rule.proto
          (portsToString rule.destPort)
          (portsToString rule.sourcePort)
          (if rule.extraFields == "" then null else rule.extraFields)
        ]))));
      fillFromParent = parent: mapAttrs (name: value: if value == "$parent$" then parent.${name} else value);
      removeLastIfEmpty = xs: if xs != [] && lib.lists.last xs == "" then lib.lists.init xs else xs;
      commentToLines = rule:
        let comment = replaceStrings ["$name$"] [rule.name] rule.comment; in
        map (x: "# " + x) (removeLastIfEmpty (lib.strings.splitString "\n" comment));
      ruleToLines = rule:
        if ! (acceptRule rule) then [] else
        (commentToLines rule)
        ++ (map (child: commentIfNotEnabled rule.enable (singleRuleToLine child)) (filter acceptRule (map (fillFromParent rule) rule.rules)));
  
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

      allTitleFields = [ "#ACTION" "SOURCE" "DEST" "PROTO" "DPORT" "SPORT" "ORIGDEST" "RATELIMIT" "USER" "MARK" "CONNLIMIT" "TIME" "HEADERS" "SWITCH" "HELPER" ];
      titleFields = (lib.lists.take (length fieldLengths) allTitleFields)
        ++ (if length fieldLengths >= length allTitleFields then [] else [ (lib.strings.concatStringsSep "    " (lib.lists.drop (length fieldLengths) allTitleFields)) ]);
      fieldLengths2 = mapMax fieldLengths (map stringLength titleFields);
      lines2 = [ titleFields ] ++ lines;

      padding = n: if n > 0 then " " + (padding (n - 1)) else "";
      padField = width: value: if stringLength value < width
        then value + padding (width - (stringLength value))
        else value;
      padFields = widths: xs:
        # don't pad the last field
        if xs == [] || tail xs == [] || widths == [] then xs
        else [ (padField (head widths) (head xs)) ] ++ (padFields (tail widths) (tail xs));
      lineToString = line: if isList line then lib.strings.concatStringsSep  "    " (padFields fieldLengths2 line) else line;
      rules = lib.strings.concatMapStringsSep "\n" lineToString lines2;
    in rules;

  someRules = {
    order = 50;
    comment = ''
      These rules are mostly copied from the two-interface example.
      see https://shorewall.org/two-interface.htm
    '';
    rules = [
      { raw = [ "Invalid(DROP)"     "net"                  "all"             "tcp" ]; }
      { raw = [ "DNS(ACCEPT)"       "$FW"                  "net" ]; }
      { raw = [ "SSH(ACCEPT)"       "loc"                  "$FW" ]; }
      { raw = [ "Ping(ACCEPT)"      "loc"                  "$FW" ]; }
      { raw = [ "Ping(ACCEPT)"      "net"                  "$FW" ]; }
      { raw = [ "ACCEPT"            "$FW"                  "loc"             "icmp" ]; }
      { raw = [ "REJECT"            "all:10.0.0.0/8,\\"          ]; iptype = "ipv4"; }
      { raw = [ ""                  "    169.254.0.0/16,\\"      ]; iptype = "ipv4"; }
      { raw = [ ""                  "    172.16.0.0/12,\\"       ]; iptype = "ipv4"; }
      { raw = [ ""                  "    192.168.0.0/16\\"       ]; iptype = "ipv4"; }
      { raw = [ ""                  ""                     "net" ]; iptype = "ipv4"; }
      { raw = [ "REJECT"            "all"                  "net:10.0.0.0/8,\\"     ]; iptype = "ipv4"; }
      { raw = [ ""                  ""                     "    169.254.0.0/16,\\" ]; iptype = "ipv4"; }
      { raw = [ ""                  ""                     "    172.16.0.0/12,\\"  ]; iptype = "ipv4"; }
      { raw = [ ""                  ""                     "    192.168.0.0/16"    ]; iptype = "ipv4"; }
      { raw = [ "ACCEPT"            "$FW"                  "net"             "icmp" ]; }
      { source = "net";
        dest   = "$FW";
        proto  = "icmp";
        iptype = "ipv6";
        destPort = "1,2,3,4,136,137";  # various errors and mtu, neighbour-solicitation/adverticement
      }
    ];
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
    PAGER=${pkgs.writeShellScript "less-R" "${pkgs.less}/bin/less -R \"$@\""}
  '';
in
{
  options = {
    services.shorewall = with lib.types; let
      ruleOptions = f: {
            enable = lib.mkOption {
              type = bool;
              default = true;
            };
            iptype = lib.mkOption {
              type = enum [ "ipv4" "ipv6" "both" "$parent$" ];
              default = f "both";
            };
            action = lib.mkOption {
              type = str;
              default = f "ACCEPT";
            };
            source = lib.mkOption {
              type = nullOr str;
              default = f null;
            };
            dest = lib.mkOption {
              type = nullOr str;
              default = f null;
            };
            proto = lib.mkOption {
              type = nullOr str;
              default = f null;
            };
            destPort = lib.mkOption {
              type = nullOr (oneOf [str port (listOf port)]);
              default = f null;
            };
            sourcePort = lib.mkOption {
              type = nullOr (oneOf [str port (listOf port)]);
              default = f null;
            };
            extraFields = lib.mkOption {
              type = str;
              default = f "";
            };
            raw = lib.mkOption {
              type = nullOr (listOf (oneOf [ str (listOf str) ]));
              description = ''
                raw text of rule

                This replaces all other fields except for order.
                The value is a list of lines. Each of them is either a string or a list of fields.
              '';
              default = null;
            };
      };
    in {
      rules = lib.mkOption {
        type = attrsOf (submodule {
          options = {
            comment = lib.mkOption {
              type = str;
              description = "comment for the rule; use an empty string to omit the comment";
              default = "$name$";
            };
            order = lib.mkOption {
              type = int;
              default = 10;
            };
            section = lib.mkOption {
              type = enum sections;
              default = "NEW";
            };
            rules = lib.mkOption {
              type = listOf (submodule { options = ruleOptions (x: "$parent$"); });
              description = "list of the actual rules; missing values will be taken from the parent";
              default = [{}];
            };
          } // (ruleOptions (x: x));
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
    services.shorewall6.enable = true;
    services.shorewall.configs = (common false) // {
      "shorewall.conf" = mainConfigFile + ''
        LOG_MARTIANS=Yes
      '';
      snat = ''
        #ACTION        SOURCE               DEST        PROTO    PORT    IPSEC    MARK    USER    SWITCH    ORIGDEST    PROBABILITY
        MASQUERADE     192.168.89.0/24      NET_IF
      '';
      rules = getRules (rule: rule.iptype == "both" || rule.iptype == "ipv4");
    };
    services.shorewall6.configs = (common true) // {
      "shorewall6.conf" = mainConfigFile;
      rules = getRules (rule: rule.iptype == "both" || rule.iptype == "ipv6");
    };
    systemd.services.shorewall.path = packages;

    #environment.systemPackages = packages;

    services.shorewall.rules.someRules = someRules;

    environment.etc.nixos-firewall.text = ''
      TCP: ${toString config.networking.firewall.allowedTCPPorts} ${toString config.networking.firewall.allowedTCPPortRanges}
      UDP: ${toString config.networking.firewall.allowedUDPPorts} ${toString config.networking.firewall.allowedUDPPortRanges}
      per interface: ${builtins.toJSON config.networking.firewall.interfaces}
    '';
  };
}
