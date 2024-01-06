{ lib, config, ... }:
{
  options = {
    environment.moreSecure = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "use slightly more secure settings (as opposed to the intentionally insecure default state)";
    };
  };
}
