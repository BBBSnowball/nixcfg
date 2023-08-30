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

  # I want persistent tinc keys even in case of a complete rebuild
  # and copy public keys from ${private} or ${privateForHost}.
  systemd.services = let
    f = name: lib.nameValuePair "tinc.${name}" {
      preStart = lib.mkBefore ''
        ${pkgs.coreutils}/bin/install -o root -m755 -d /etc/tinc/${name}
        ${pkgs.coreutils}/bin/install -o tinc.${name} -m755 -d /etc/tinc/${name}/hosts
        ${pkgs.coreutils}/bin/install -o root -m400 /etc/nixos/secret_local/tinc-${name}-rsa_key.priv /etc/tinc/${name}/rsa_key.priv
        if [ -e "${privateForHost}/tinc-pubkeys/${name}" ] ; then
          ${pkgs.rsync}/bin/rsync -r --delete --copy-links --perms --chmod=F444,D755 --chown=tinc.${name} ${privateForHost}/tinc-pubkeys/${name}/ /etc/tinc/${name}/hosts
        else
          ${pkgs.rsync}/bin/rsync -r --delete --copy-links --perms --chmod=F444,D755 --chown=tinc.${name} ${private}/tinc-pubkeys/${name}/ /etc/tinc/${name}/hosts
        fi
      '';
    };
  in builtins.listToAttrs (map f ["bbbsnowball" "door" "a"]);
}
