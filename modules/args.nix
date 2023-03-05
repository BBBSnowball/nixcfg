{ config, ... }@args:
let
  private = config._module.args.private or (throw "`private` is not available in config._module.args");
  hostName = config.networking.hostName;
in
{
  _module.args = {
    privateForHost = let
      outPath = "${private}/by-host/${hostName}";
      imported = import outPath;
      values = if !(builtins.pathExists "${outPath}/default.nix")
      then {}
      else if builtins.isFunction imported
      then imported args
      else imported;
    in values // { inherit outPath; };
    secretForHost = "/etc/nixos/secret/by-host/${hostName}";
  };
}
