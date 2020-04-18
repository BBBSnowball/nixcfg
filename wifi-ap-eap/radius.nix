{ config, pkgs, lib, ... }:
let
  radius = pkgs.freeradius;
  cfg = config.services.wifi-ap-eap;
  secretsDir = cfg.secretsDir;
  configDir = derivation {
    name = "radius-config";
    builder = ./mkconfig.sh;
    #system = builtins.currentSystem;
    system = pkgs.system;

    inherit (pkgs) coreutils patch;
    inherit secretsDir;
    src = "${radius}/etc/raddb";
    configPatch = ./config.patch;
  };
  initScript = pkgs.writeShellScript "freeradius-init.sh" ''
    set -e
    umask 077
    mkdir -p ${secretsDir}
    cd ${secretsDir}
    if [ ! -f client-secret.conf ] ; then
      echo -n "secret = " >client-secret.conf.tmp
      ${pkgs.openssl}/bin/openssl rand -hex 20 >>client-secret.conf.tmp
      mv client-secret.conf.tmp client-secret.conf
    fi
    #FIXME generate certs
    touch init-done
  '';
in {
  config = lib.mkIf cfg.enable {
    warnings = if cfg.serverCertValidDays == 60 && cfg.clientCertValidDays == 60
      then ["Certificates will expire after 60 days unless you change the default values of services.wifi-ap-eap.serverCertValidDays and clientCertValidDays!"]
      else [];

    services.freeradius.enable = true;
    services.freeradius.configDir = configDir;
    # test: radtest -x username password 127.0.0.1:18120 10 testing123
  
    # NixOS unstable has debug disabled by default. As we are still on 19.09,
    # we have to overwrite the start command to disable it.
    systemd.services.freeradius.serviceConfig.ExecStart
      = lib.mkForce "${pkgs.freeradius}/bin/radiusd -f -d ${config.services.freeradius.configDir} -l stdout";
  
    systemd.services.freeradius.serviceConfig.StateDirectory = "radiusd";
  
    systemd.services.freeradius-init = {
      description = "Generate keys and other secrets for radius server.";
      wantedBy = [ "freeradius.service" ];
      serviceConfig = {
        Type = "oneshot";
        Creates = "${secretsDir}/init-done";
        ExecStart = initScript;
      };
    };
  };
}
