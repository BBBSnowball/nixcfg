with builtins;
let
  lock = fromJSON (readFile ./flake.lock);
  flake-compat =
    if lock.nodes.flake-compat.locked ? url && substring 0 7 lock.nodes.flake-compat.locked.url == "file://"
    then substring 7 (-1) lock.nodes.flake-compat.locked.url
    else fetchTarball {
      url = "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
      sha256 = lock.nodes.flake-compat.locked.narHash;
    };
  flake = import flake-compat { src = ./.; };
  hostnameFromEnv = getEnv "NIXOS_BUILD_FOR_HOSTNAME";
  hostname = if hostnameFromEnv != "" then hostnameFromEnv else replaceStrings ["\n"] [""] (readFile "/etc/hostname");
in flake.defaultNix.nixosModules."hosts-${hostname}"
