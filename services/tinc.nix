{ config, pkgs, lib, ... }:
{
  services.tinc.networks.bbbsnowball = {
    name = "sonline";
    hosts = {<redacted>};
    listenAddress = config.networking.upstreamIp;
    package = pkgs.tinc;  # the other nodes use stable so no need to use the pre-release
    interfaceType = "tap";  # must be consistent across the network
    chroot = true; #TODO could be a problem for scripts
    extraConfig = ''
      AddressFamily=ipv4
      Mode=switch
      LocalDiscovery=no
    '';
  };

  services.tinc.networks.door = {
    name = "sonline";
    hosts = {<redacted>};
    listenAddress = config.networking.upstreamIp;
    package = pkgs.tinc;  # the other nodes use stable so no need to use the pre-release
    interfaceType = "tap";  # must be consistent across the network
    chroot = true; #TODO could be a problem for scripts
    extraConfig = ''
      AddressFamily=ipv4
      Mode=switch
      LocalDiscovery=no
      Port=656

      ClampMSS=yes
      IndirectData=yes
    '';
  };

  networking.firewall.allowedPorts.tinc-tcp = { port = 655; type = "tcp"; };  # default port
  networking.firewall.allowedPorts.tinc-udp = { port = 655; type = "udp"; };  # default port
  networking.firewall.allowedPorts.tinc-tcp-door = { port = 656; type = "tcp"; };
  networking.firewall.allowedPorts.tinc-udp-door = { port = 656; type = "udp"; };

  # I want persistent tinc keys even in case of a complete rebuild.
  systemd.services."tinc.bbbsnowball".preStart = lib.mkBefore ''
    mkdir -p mkdir -p /etc/tinc/bbbsnowball
    ( umask 077; cp -u /etc/nixos/secret/tinc-bbbsnowball-rsa_key.priv /etc/tinc/bbbsnowball/rsa_key.priv )
  '';
  systemd.services."tinc.door".preStart = lib.mkBefore ''
    mkdir -p mkdir -p /etc/tinc/door
    ( umask 077; cp -u /etc/nixos/secret/tinc-door-rsa_key.priv /etc/tinc/door/rsa_key.priv )
  '';
}
