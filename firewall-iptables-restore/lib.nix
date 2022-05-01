{ pkgs ? import <nixpkgs> {}, lib ? pkgs.lib, ... }:
with builtins;
with lib;
rec {
  compareP = path: a: b: let
    compare' = path: ab: if length ab == 2 then compareP path (elemAt ab 0) (elemAt ab 1) else "only present in one of them ${path}";
    compare'' = path: ab: if ab ? fst && ab ? snd then compareP path ab.fst ab.snd else "only present in one of them ${path}";

    bothHaveOutPath = a ? outPath && b ? outPath;
    compareOutPath = if a.outPath == b.outPath then null else "difference at ${path}.outPath: ${a.outPath} != ${b.outPath}";

    firstNonNull = xs: if xs == [] then null else if ! isNull (head xs) then head xs else firstNonNull (tail xs);

    compareAttrs = firstNonNull (attrValues (attrsets.zipAttrsWith compareAttr [a b]));
    compareAttr = name: ab: compare' "${path}.${name}" ab;

    compareListElems = firstNonNull (lists.imap0 (i: ab: compare'' "${path}.#${toString i}" ab) (lists.zipLists a b));
    compareLists =
      if compareListElems != null then compareListElems
      else if length a != length b
      then "difference at ${path}.#length: ${toString (length a)} != ${toString (length b)}"
      else null;

    lines = strings.splitString "\n";
    compareStrings =
      if strings.hasInfix "\n" a then compareP "${path}.#lines" (lines a) (lines b)
      else if a != b then "difference at ${path}: ${a} != ${b}"
      else null;
  in if stringLength path > 100
    then throw "very long path at ${path}"
    else if typeOf a != typeOf b
    then "different type at ${path}: ${typeOf a} != ${typeOf b}"
    else if isAttrs a && isAttrs b && bothHaveOutPath
    then compareOutPath
    else if isAttrs a && isAttrs b
    then compareAttrs
    else if isFunction a && isFunction b
    then null
    else if isList a && isList b
    then compareLists
    else if isString a && isString b
    then compareStrings
    else if a != b
    then "difference at ${path}"
    else null;
  compare = compareP "#";


  stripNonJsonP = depth: a:
    if depth > 30
    then "<too deep>"
    else if isAttrs a && a ? outPath
    then { inherit (a) outPath; }
    else if isAttrs a
    then lib.mapAttrs (_: x: stripNonJsonP (depth+1) x) a
    else if isFunction a
    then "<function>"
    else if isList a
    then builtins.map (stripNonJsonP (depth+1)) a
    else a;
  stripNonJson = stripNonJsonP 0;
}
