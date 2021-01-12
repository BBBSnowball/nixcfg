{ self ? {}
, pkgs ? self.inputs.nixpkgs or (import <nixpkgs> {})
, lib ? self.lib or (import ./lib.nix { inherit pkgs; })
, flakeInputs ? self.inputs or { jens-dotfiles = ./submodules/jens-dotfiles; } }:
let
  withInputs = lib.provideArgsToModule (flakeInputs // { inherit modules; });
  internalModules = {
  };
  publicModules = {
    # not all of these are useful for other systems
    #FIXME remove those that are not
    wifi-ap-eap = ./wifi-ap-eap/default.nix;
    zsh = withInputs ./zsh.nix;
    smokeping = ./smokeping.nix;
    ntopng = ./ntopng.nix;
    samba = ./samba.nix;
    tinc = ./tinc.nix;
    shorewall = ./shorewall.nix;
    dhcpServer = ./dhcp-server.nix;
    pppd = ./pppd.nix;
    syslog-udp = ./bbverl/syslog-udp.nix;
    rabbitmq = ./bbverl/rabbitmq.nix;
    fhem = ./bbverl/fhem.nix;
    ddclient = ./bbverl/ddclient.nix;
    homeautomation = ./homeautomation;
    loginctl-linger = ./loginctl-linger.nix;
    fix-sudo = ./fix-sudo.nix;
    common = withInputs ./common.nix;
    enable-flakes = withInputs ./enable-flakes.nix;
    nvim = withInputs ./nvim.nix;
    emacs = ./emacs.nix;
    snowball = withInputs ./snowball.nix;
    snowball-big = withInputs ./snowball-big.nix;
    snowball-desktop = withInputs ./snowball-desktop.nix;
    snowball-headless = withInputs ./snowball-headless.nix;
    snowball-headless-big = withInputs ./snowball-headless-big.nix;
    auto-upgrade = ./auto-upgrade.nix;
    extra-container = ./extra-container.nix;
    snowball-vm-sonline0 = withInputs ./snowball-vm-sonline0.nix;
    snowball-vm = withInputs ./snowball-vm.nix;
    debug = ./debug.nix;
  };
  modules = publicModules // internalModules;
in publicModules
