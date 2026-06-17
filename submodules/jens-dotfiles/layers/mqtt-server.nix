{ ... }:
{
  services.mosquitto = {
    enable = true;
    allowAnonymous = true;
    host = "0.0.0.0";
    users = {};
    aclExtraConf = ''
      pattern readwrite #
    '';
    extraConf = ''
      listener 1884
      protocol websockets
    '';
  };
}
