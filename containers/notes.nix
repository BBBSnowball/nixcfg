{ config, lib, modules, pkgs, nixpkgs, nixpkgs-notes, ... }:
let
  inherit (pkgs) system;
  ports = config.networking.firewall.allowedPorts;
in {
  containers.notes = {
    autoStart = true;
    config = { config, pkgs, ... }: let
      overlay = self: super: {
        #TODO Install Python libraries to system, use overridePythonAttrs to adjust version (see esphome)
        #TODO upgrade to Python 3
        magpiePython = self.python27.withPackages (ps: with ps; [
          setuptools pip virtualenv
        ]);
        # I thought that fetchSubmodules was ignored but I was looking in the wrong place.
        # I should test this sometime and revert back to it if it works.
        #magpie = self.fetchFromGitHub {
        #  owner = "BBBSnowball";
        #  repo  = "magpie";
        #  rev   = "e9dec30f4db96f26f90a07a0b8e31410d194a273"; # branch no-external-servers
        #  sha256 = "1kx4mq39kdfcm29p0bk5xg82gmgj0dl7kab6h77m4635bkdq6m81";
        #  fetchSubmodules = true;
        #};
        magpie = self.fetchgit {
          name = "magpie-src";
          url = "https://github.com/BBBSnowball/magpie.git";
          rev   = "e9dec30f4db96f26f90a07a0b8e31410d194a273"; # branch no-external-servers
          fetchSubmodules = true;
          sha256 = "0046jnf3qp95pvadfx9nz63xw0p7qx3hn4zqf09gs0vf2wscgbj3";
        };
        buildMagpieEnv = with self; self.writeShellScriptBin "buildMagpieEnv" ''
          out=~/magpie-env
          if [ ! -d $out ] ; then ${magpiePython}/bin/virtualenv -p ${magpiePython}/bin/python $out ; fi
          source $out/bin/activate
          pip install -r ${magpie}/requirements.txt
          pip install future
          ${gnused}/bin/sed -i 's#libname = ctypes.util.find_library.*#libname = \"${file}/lib/libmagic${stdenv.hostPlatform.extensions.sharedLibrary}\"#' $out/lib/python2.7/site-packages/magic/api.py
          # workaround: setuptools writes the egg file to the local directory
          cp -r ${magpie} /tmp/magpie
          chmod -R +w /tmp/magpie
          cd /tmp/magpie && python setup.py install
          # static dir is not installed, for some reason
          cp -r /tmp/magpie/magpie/static $out/lib/python2.7/site-packages/magpie-0.1.0-py2.7.egg/magpie/
          rm -rf /tmp/magpie
        '';
        magpieWebConfig = self.writeText "web.cfg" ''
          address='localhost'
          autosave=False
          autosave_interval=5
          port=${toString ports.notes-magpie.port}
          pwdhash=${"''"}
          repo='/home/magpie/notes'
          testing=False
          theme='/magpie/static/css/bootstrap.min.css'
          username=${"''"}
          wysiwyg=False
          prefix='/magpie/'
        '';
        initMagpieScript = self.writeShellScriptBin "initMagpie" ''
          mkdir -p ~/.magpie
          cp ${self.magpieWebConfig} ~/.magpie/web.cfg
          
          ${self.buildMagpieEnv}/bin/buildMagpieEnv

          #NOTE We may have to create ~magpie/notes for a new setup but I'm going to
          #     copy the data from the old systemd.
        '';
      };
      # https://github.com/NixOS/nixpkgs/issues/88621
      pkgs = import nixpkgs-notes { overlays = [ overlay ]; inherit system; };
    in {
      imports = [ modules.container-common ];

      environment.systemPackages = with pkgs; [
        magpie magpiePython initMagpieScript gcc stdenv gnused git socat
      ];

      # https://github.com/NixOS/nixpkgs/issues/88621
      nixpkgs.pkgs = pkgs;

      nixpkgs.overlays = [ overlay ];

      users.users.magpie = {
        isNormalUser = true;
        extraGroups = [ ];
      };

      system.activationScripts.magpie = lib.stringAfter ["users" "groups"] ''
        # make virtualenv for magpie
        ${pkgs.su}/bin/su magpie -c "${pkgs.initMagpieScript}/bin/initMagpie"
      '';

      systemd.services.magpie = {
        description = "Magpie (Notes)";
        serviceConfig = {
          User = "magpie";
          Group = "users";
          ExecStart = "${pkgs.bash}/bin/bash -c '. ~/magpie-env/bin/activate && magpie'";
          WorkingDirectory = "/home/magpie";
          KillMode = "process";

          RestartSec = "10";
          Restart = "always";
        };
        path = with pkgs; [ git magpiePython ];
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" "fs.target" ];
      };

      # I'm too lazy to change the Magpie service to listen not only on lo
      # or how to successfully DNAT to localhost. Therefore, I'm using socat
      # to bridge the gap.
      #FIXME I should find a proper solution for this.
      systemd.services.magpie-socat = {
        description = "Forward to Magpie";
        serviceConfig = {
          User = "magpie";
          Group = "users";
          ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${toString ports.notes-magpie-ext.port},fork TCP-CONNECT:127.0.0.1:${toString ports.notes-magpie.port}";
          RestartSec = "10";
          Restart = "always";
        };
        wantedBy = [ "multi-user.target" ];
        after = [ "magpie" ];
      };
    };
  };

  networking.firewall.allowedPorts.notes-magpie  = 8082;
  networking.firewall.allowedPorts.notes-magpie-ext = 8083;
}
