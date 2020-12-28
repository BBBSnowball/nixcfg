{
  description = "Config for routeromen, some modules are also used on other hosts";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";

  outputs = { self, nixpkgs }@flakeInputs: {
    lib.provideArgsToModule = args: m: args2: with nixpkgs.lib;
      if isFunction m || isAttrs m
        then unifyModuleSyntax "<unknown-file>" "" (applyIfFunction "" m (args // args2))
        else unifyModuleSyntax (toString m) (toString m) (applyIfFunction (toString m) (import m) (args // args2));

    # not all of these are useful for other systems
    #FIXME remove those that are not
    nixosModules.wifi-ap-eap = ./wifi-ap-eap/default.nix;
    nixosModules.zsh = ./zsh.nix;
    nixosModules.smokeping = ./smokeping.nix;
    nixosModules.ntopng = ./ntopng.nix;
    nixosModules.samba = ./samba.nix;
    nixosModules.tinc = ./tinc.nix;
    nixosModules.shorewall = ./shorewall.nix;
    nixosModules.dhcpServer = ./dhcp-server.nix;
    nixosModules.pppd = ./pppd.nix;
    nixosModules.syslog-udp = ./bbverl/syslog-udp.nix;
    nixosModules.rabbitmq = ./bbverl/rabbitmq.nix;
    nixosModules.fhem = ./bbverl/fhem.nix;
    nixosModules.ddclient = ./bbverl/ddclient.nix;
    nixosModules.homeautomation = ./homeautomation;
    nixosModules.loginctl-linger = ./loginctl-linger.nix;
    nixosModules.fix-sudo = ./fix-sudo.nix;
 
    nixosConfigurations.routeromen = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules =
        [ (self.lib.provideArgsToModule flakeInputs ./configuration.nix)
          ({ pkgs, ... }: {
            _file = "${self}/flake.nix#inline-config";
            # Let 'nixos-version --json' know about the Git revision
            # of this flake.
            system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
          })
        ];
    };
  };
}
