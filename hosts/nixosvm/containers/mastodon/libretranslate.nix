{ ports, ... }:
{
  services.libretranslate = {
    enable = true;
    port = ports.libretranslate.port;
    disableWebUI = true;
  };
}
