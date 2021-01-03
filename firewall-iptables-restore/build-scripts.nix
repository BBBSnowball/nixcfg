{ config, pkgs, lib, ... }:
with builtins;
with lib;
let
  cfg = config.networking.firewall.iptables-restore;
  tables = config.networking.firewall.iptables.tables;

  genScript = which:
  let
    genLinesForTables = strings.concatStrings (attrsets.mapAttrsToList (name: value: "## table ${name} ##\n\n" + genLinesForChains (tablePrefix name) value) tables);
    tablePrefix = name: if name == "filter" then "" else "-t ${name} ";
    genLinesForChains = prefix: chains: strings.concatStrings (attrsets.mapAttrsToList (genLinesForChain prefix) chains);
    genLinesForChain = prefix: name: info: optionalString info.enable
      ( "### chain ${name} ###\n\n"
      + (optionalString (info.header != "") (info.header + "\n"))
      + (optionalString (shouldCreate name info) ("${prefix}-N ${name}\n"))
      + (optionalString (info.policy != null) ("${prefix}-P ${name} ${info.policy}\n"))
      + (optionalString (info.header != "" || info.policy != null || shouldCreate name info) "\n")
      + (addPrefix "${prefix}-A ${name} " (genRules info.rules)));
    shouldCreate = name: info: if isNull info.create then startsWithLowerCase name else info.create;
    startsWithLowerCase = x: let firstChar = substring 0 1 x; in firstChar == strings.toLower firstChar;
    genRules = rules: strings.concatMapStrings (genRule (attrNames rules != ["default"])) (sortRules rules);
    sortRules = rules: lists.sort ltRule (attrsets.mapAttrsToList (name: value: value // { inherit name; }) rules);
    ltRule = a: b: lists.compareLists compare [ a.order a.name ] [ b.order b.name ] < 0;
    genRule = withLabelHeader: rule: optionalString rule.enable
      ( (optionalString withLabelHeader "#### label ${rule.name} ####\n\n")
      + (optionalString (rule.rules != "") (rule.rules + "\n"))
      + (let xs = if which == "ipv4" then rule.rules4 else rule.rules6; in optionalString (xs != "") (xs + "\n"))
      + "\n");
    addPrefix = prefix: text: addPrefix' prefix (split "((^|[^\\\\][\n])[[:space:]]*)(#-|-)" text);
    addPrefix' = prefix: parts:
      let
        part1 = head parts;
        match = head (tail parts);
        rest = tail (tail parts);
        part2 = head match;
        part3 = head (tail (tail match));
      in if length parts == 1 then part1 else part1 + part2 + prefix + part3 + addPrefix' prefix (tail (tail parts));
  in pkgs.writeText "iptables-restore-${which}" genLinesForTables;
in
{
  config.networking.firewall.iptables-restore = mkDefault {
    script-ipv4 = genScript "ipv4";
    script-ipv6 = genScript "ipv6";
  };
}
