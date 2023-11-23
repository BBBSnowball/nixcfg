{ ... }:
{
  services.coturn = {
    enable = true;
    no-auth = true;
    extraConfig = ''
      stun-only
    '';
  };
}
