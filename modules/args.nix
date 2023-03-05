{ config, ... }:
let
  private = config._module.args.private or (throw "`private` is not available in config._module.args");
  hostName = config.networking.hostName;
in
{
  _module.args = {
    privateForHost = let
      outPath = "${private}/by-host/${hostName}";
      #FIXME make config available to a function in values
      values = if builtins.pathExists "${outPath}/default.nix" then import outPath else {};
    in values // { inherit outPath; };
    secretForHost = "/etc/nixos/secret/by-host/${hostName}";
  };
}
