{ pkgs, privateForHost, secretForHost, ... }:
let
  #mailinaboxPath = "${privateForHost}/mailinabox";  # in Nix store, not what we want
  #firewallRulesDir = "${secretForHost}/firewall";
  mailinaboxPath = "/etc/nixos/private/private/by-host/sonline0/mailinabox";
  firewallRulesDir = "/etc/nixos/secret/by-host/sonline0/firewall";
  firewallRules4Path = "${firewallRulesDir}/rules.rb";
  firewallRules6Path = "${firewallRulesDir}/rules.v6";
in
{
  environment.shellAliases = {
    cd-mailinabox = "cd ${mailinaboxPath}";
    cd-iptables = "cd ${firewallRulesDir}";
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "mailinabox-edit" ''set -x; exec vi ${mailinaboxPath}/*.nix'')
    (writeShellScriptBin "mailinabox-apply" ''set -x; /etc/nixos/flake/hosts/mailinabox/run.sh interactive-apply'')
    (writeShellScriptBin "mailinabox-tig" ''set -x; exec tig -C "${mailinaboxPath}" "$@"'')

    (writeShellScriptBin "iptables-edit" ''set -x; exec vi ${firewallRules4Path} ${firewallRules6Path}'')
    (writeShellScriptBin "iptables-tig" ''set -x; exec tig -C "${firewallRulesDir}" "$@"'')
    (writeShellScriptBin "iptables-test" ''set -x; ruby ${firewallRules4Path} | iptables-restore && ip6tables-restore <${firewallRules6Path}'')
    (runCommand "iptables-apply" {
      inherit (pkgs) runtimeShell;
      inherit (pkgs.stdenv) shell;
      dir = firewallRulesDir;
    } ''
      mkdir -p $out/bin
      substitute ${./iptables-apply.sh} $out/bin/iptables-apply \
        --subst-var runtimeShell \
        --subst-var dir
    '')
  ];
}
