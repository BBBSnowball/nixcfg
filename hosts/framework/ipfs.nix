{ ... }:
{
  services.kubo = {
    enable = true;
    # This setting seems to be ignored.
    settings.Addresses.API = [ "ip4/127.0.0.1/tcp/8090" ];
  };
}
