{ config, pkgs, lib, private, privateForHost, ... }:
let
  readKeys = dir: with builtins; with lib;
    attrsets.filterAttrs (name: value: ! isNull value)
    (mapAttrs (name: type: if type == "regular" && ! strings.hasSuffix ".old" name then readFile (dir + "/${name}") else null)
    (readDir dir));
  
  tincCommon = name: {
    name = "sonline";
    hosts = let
      loc1 = "${privateForHost}/tinc-pubkeys/${name}";
      loc2 = "${private}/tinc-pubkeys/${name}";
    in readKeys (if builtins.pathExists loc1 then loc1 else loc2);
    listenAddress = config.networking.upstreamIp;
    package = pkgs.tinc;  # the other nodes use stable so no need to use the pre-release
    interfaceType = "tap";  # must be consistent across the network
    chroot = true; #TODO could be a problem for scripts
  };
in
{
  services.tinc.networks.bbbsnowball = (tincCommon "bbbsnowball") // {
    extraConfig = ''
      AddressFamily=ipv4
      Mode=switch
      LocalDiscovery=no
    '';
  };

  services.tinc.networks.door = (tincCommon "door") // {
    extraConfig = ''
      AddressFamily=ipv4
      Mode=switch
      LocalDiscovery=no
      Port=656

      ClampMSS=yes
      IndirectData=yes
    '';
  };

  services.tinc.networks.a = (tincCommon "a") // {
    extraConfig = ''
      AddressFamily=ipv4
      Mode=switch
      LocalDiscovery=no
      Port=657

      ClampMSS=yes
      IndirectData=yes
    '';
  };

  networking.firewall.allowedPorts.tinc-tcp = { port = 655; type = "tcp"; };  # default port
  networking.firewall.allowedPorts.tinc-udp = { port = 655; type = "udp"; };  # default port
  networking.firewall.allowedPorts.tinc-tcp-door = { port = 656; type = "tcp"; };
  networking.firewall.allowedPorts.tinc-udp-door = { port = 656; type = "udp"; };
  networking.firewall.allowedPorts.tinc-tcp-a = { port = 657; type = "tcp"; };
  networking.firewall.allowedPorts.tinc-udp-a = { port = 657; type = "udp"; };

  # I want persistent tinc keys even in case of a complete rebuild.
  #FIXME change secret to secret_local !!
  systemd.services."tinc.bbbsnowball".preStart = lib.mkBefore ''
    mkdir -p /etc/tinc/bbbsnowball
    ( umask 077; cp -u /etc/nixos/secret/tinc-bbbsnowball-rsa_key.priv /etc/tinc/bbbsnowball/rsa_key.priv )
  '';
  systemd.services."tinc.door".preStart = lib.mkBefore ''
    mkdir -p /etc/tinc/door
    ( umask 077; cp -u /etc/nixos/secret/tinc-door-rsa_key.priv /etc/tinc/door/rsa_key.priv )
  '';
  systemd.services."tinc.a".preStart = lib.mkBefore ''
    mkdir -p /etc/tinc/a
    ( umask 077; cp -u /etc/nixos/secret/tinc-a-rsa_key.priv /etc/tinc/a/rsa_key.priv )
  '';
}
