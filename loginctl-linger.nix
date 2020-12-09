# see https://github.com/michalrus/dotfiles/commit/ebd5fa9583f82589f23531647aa677feb3f8d344#diff-4d353005ef5b3e37f33c07332b8523edR1
{ config, lib, pkgs, ... }:

# A temporary hack to `loginctl enable-linger $somebody` (for
# multiplexer sessions to last), until this one is unresolved:
# https://github.com/NixOS/nixpkgs/issues/3702
#
# Usage: `users.extraUsers.somebody.linger = true` or slt.

with lib;

let

  dataDir = "/var/lib/systemd/linger";

  lingeringUsers = map (u: u.name) (attrValues (flip filterAttrs config.users.users (n: u: u.linger)));

  lingeringUsersFile = builtins.toFile "lingering-users"
    (concatStrings (map (s: "${s}\n")
      (sort (a: b: a < b) lingeringUsers))); # this sorting is important for `comm` to work correctly

  updateLingering = pkgs.writeScript "update-lingering" ''
    if [ -e ${dataDir} ] ; then
      ls ${dataDir} | sort | comm -3 -1 ${lingeringUsersFile} - | xargs -r ${pkgs.systemd}/bin/loginctl disable-linger
      ls ${dataDir} | sort | comm -3 -2 ${lingeringUsersFile} - | xargs -r ${pkgs.systemd}/bin/loginctl  enable-linger
    fi
  '';

in

{
  options = {
    users.defaultLinger = mkEnableOption "lingering for all users (can be overridden per user)";
    users.users = mkOption {
      options = [{
        linger = mkEnableOption "lingering for the user" // { default = config.users.defaultLinger; };
      }];
    };
  };

  config = {
    system.activationScripts.update-lingering =
      stringAfter [ "users" ] updateLingering;
  };
}
