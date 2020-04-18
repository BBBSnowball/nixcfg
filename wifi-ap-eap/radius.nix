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
    # generate patch like this:
    # diff -Naur --no-dereference default-config/ config/ >config.patch
    configPatch = ./config.patch;
  };
  addCertOptions = file: cn: days: ''
    echo ${lib.escapeShellArg "countryName           = ${cfg.countryName}"}         >>${file}
    echo ${lib.escapeShellArg "stateOrProvinceName   = ${cfg.stateOrProvinceName}"} >>${file}
    echo ${lib.escapeShellArg "localityName          = ${cfg.localityName}"}        >>${file}
    echo ${lib.escapeShellArg "organizationName      = ${cfg.organizationName}"}    >>${file}
    echo ${lib.escapeShellArg "emailAddress          = ${cfg.emailAddress}"}        >>${file}
    echo ${lib.escapeShellArg "commonName            = ${cn}"}                      >>${file}
    sed -i 's/^\(default_days *= *\).*/\1${toString days}/' ${file}
  '';
  initScript = pkgs.writeShellScript "freeradius-init.sh" ''
    set -e
    umask 077
    mkdir -p ${secretsDir}
    chown radius ${secretsDir}
    cd ${secretsDir}
    if [ ! -f client-secret.conf ] ; then
      echo -n "secret = " >client-secret.conf.tmp
      openssl rand -hex 20 >>client-secret.conf.tmp
      mv client-secret.conf.tmp client-secret.conf
      chown radius client-secret.conf
    fi
    if [ ! -f users ] ; then
      touch users
      chown -R radius users
    fi
    if [ ! -e certs ] ; then
      rm -rf certs.tmp
      cp -r ${configDir}/certs.example certs.tmp
      cd certs.tmp
      ${addCertOptions "ca.cnf"           cfg.commonNameCA     cfg.serverCertValidDays}
      ${addCertOptions "server.cnf"       cfg.commonNameServer cfg.serverCertValidDays}
      ${addCertOptions "inner-server.cnf" cfg.commonNameInner  cfg.serverCertValidDays}
      ${addCertOptions "client.cnf"       "dummy"              cfg.clientCertValidDays}
      make destroycerts dh server ca inner-server
      c_rehash .
      chown -R radius .
      cd ..
      mv certs.tmp certs
    fi
  '';

  manageScript = pkgs.writeShellScriptBin "nixos-wifi-ap-eap" (''
    SERVERNAME=${lib.escapeShellArg cfg.commonNameInner}
    SECRETS_DIR=${lib.escapeShellArg secretsDir}
    CERTS_DIR=${lib.escapeShellArg secretsDir}/certs
    SSID=${lib.escapeShellArg config.services.hostapd.ssid}
    CLIENT_CERT_VALID_DAYS=${toString cfg.clientCertValidDays}
    export PATH=${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.pwgen}/bin:${pkgs.openssl}/bin:${pkgs.zip}/bin

  '' + (builtins.readFile ./nixos-wifi-ap-eap-tail));
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
      # Perl is required for OpenSSL's c_rehash script.
      path = with pkgs; [ coreutils openssl gnumake gnused gnugrep perl ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = initScript;
      };
    };

    environment.systemPackages = [manageScript];
  };
}
