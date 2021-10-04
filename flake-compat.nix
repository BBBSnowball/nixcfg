with builtins; let
  lock = fromJSON (readFile ./flake.lock);
  locked = lock.nodes.flake-compat.locked;
  flake-compat =
    if locked ? url && substring 0 7 locked.url == "file://"
    then substring 7 (-1) lock.nodes.flake-compat.locked.url
    else with locked; fetchTarball {
      url = "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";
      sha256 = narHash;
    };
in import flake-compat
