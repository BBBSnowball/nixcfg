{ self ? {}
, pkgs ? self.inputs.nixpkgs or (import <nixpkgs> {})
, lib ? self.lib or (import ./lib.nix { inherit pkgs; })
, flakeInputs ? self.inputs or { jens-dotfiles = ./submodules/jens-dotfiles; } }:
let
  withInputs = lib.provideArgsToModule (flakeInputs // { inherit modules; });
  modulesFromDir = dir: with builtins; let
    lib = pkgs.lib;
    f = name: type: if (type == "regular" || type == "symlink") && !isNull (match "([^.].*)[.]nix" name)
    then { name = head (match "([^.].*)[.]nix" name); value = withInputs (dir + "/${name}"); }
    else if type == "directory" && ! isNull (match "[^.].*" name)
    then { inherit name; value = modulesFromDir (dir + "/${name}"); }
    else null;
    in lib.attrsets.filterAttrs (name: value: ! isNull value) (lib.attrsets.mapAttrs' f (builtins.readDir dir));
  internalModules = {
  };
  publicModules = (modulesFromDir ./modules) // (pkgs.lib.attrsets.mapAttrs (name: withInputs) {
    # not all of these are useful for other systems
    #FIXME remove those that are not
    wifi-ap-eap = ./wifi-ap-eap/default.nix;
    smokeping = ./smokeping.nix;
    ntopng = ./ntopng.nix;
    samba = ./samba.nix;
    tinc = ./tinc.nix;
    dhcpServer = ./dhcp-server.nix;
    pppd = ./pppd.nix;
    syslog-udp = ./bbverl/syslog-udp.nix;
    rabbitmq = ./bbverl/rabbitmq.nix;
    fhem = ./bbverl/fhem.nix;
    ddclient = ./bbverl/ddclient.nix;
    homeautomation = ./homeautomation;
  });
  modules = publicModules // internalModules;
in publicModules
