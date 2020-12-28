{ pkgs, ... }:
{
  provideArgsToModule = args: m: args2: with pkgs.lib;
    if isFunction m || isAttrs m
      then unifyModuleSyntax "<unknown-file>" "" (applyIfFunction "" m (args // args2))
      else unifyModuleSyntax (toString m) (toString m) (applyIfFunction (toString m) (import m) (args // args2));
}
