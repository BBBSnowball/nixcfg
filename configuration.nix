with builtins;
let
  flake = import ./flake-compat.nix { src = ./.; };

  hostnameFromEnv = getEnv "NIXOS_BUILD_FOR_HOSTNAME";
  hostname = if hostnameFromEnv != "" then hostnameFromEnv else replaceStrings ["\n"] [""] (readFile "/proc/sys/kernel/hostname");
  hostdir = ./. + "/hosts/${hostname}";
  hostdirFlake = import flake-compat { src = hostdir; };
in
  if pathExists "${hostdir}/configuration.nix"
  then import "${hostdir}/configuration.nix"
  else if pathExists "${hostdir}/flake.nix"
  then hostdirFlake.defaultNix.nixosModules.default
  else flake.defaultNix.nixosModules."hosts-${hostname}" or flake.defaultNix.nixosModules.default
