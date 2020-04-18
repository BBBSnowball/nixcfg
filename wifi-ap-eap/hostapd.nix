{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.hostapd;
  cfg2 = config.services.wifi-ap-eap;

  configFile = pkgs.writeText "hostapd.conf" ''
    # copied from nixos/modules/services/networking/hostapd.nix
    interface=${cfg.interface}
    driver=${cfg.driver}
    ssid=${cfg.ssid}
    hw_mode=${cfg.hwMode}
    channel=${toString cfg.channel}
    # logging (debug level)
    logger_syslog=-1
    logger_syslog_level=2
    logger_stdout=-1
    logger_stdout_level=2
    ctrl_interface=/run/hostapd
    ctrl_interface_group=${cfg.group}
    ${optionalString cfg.noScan "noscan=1"}
    ${cfg.extraConfig}

    # our additions
    country_code=${cfg2.countryCode}

    wpa=2
    #wpa_key_mgmt=SAE   # WPA 3
    wpa_key_mgmt=WPA-EAP
    rsn_pairwise=CCMP CCMP-256 GCMP GCMP-256
    ieee8021x=1 
    auth_algs=1

    nas_identifier=${cfg2.serverName}

    auth_server_addr=127.0.0.1
    auth_server_port=18120
    own_ip_addr=127.0.0.1
    #dynamic_vlan=0

    acct_server_addr=127.0.0.1
    acct_server_port=1813
  '';

  secretConfigFile = "${cfg2.secretsDir}/hostapd.conf";

  createConfigWithSecret = pkgs.writeShellScript "create-hostapd-config.sh" ''
    secret=`${pkgs.gnused}/bin/sed -n 's/secret *= *//p' ${cfg2.secretsDir}/client-secret.conf`
    ( echo "# copied from ${configFile}"
      cat ${configFile}
      echo ""
      echo "# secret values"
      echo "auth_server_shared_secret=$secret"
      echo "acct_server_shared_secret=$secret" ) >${secretConfigFile}
  '';

  setFourAddressMode =
    if cfg2.wifiFourAddressMode == null
      then []
      else [("${pkgs.iw}/bin/iw dev ${cfg.interface} set 4addr "
        + (if cfg2.wifiFourAddressMode then "on" else "off"))];
in {
  config = lib.mkIf cfg2.enable {
    assertions = [
      # The default value is empty but that breaks the generated systemd service.
      { assertion = cfg.interface != "";
        message = "Please configure interface in services.hostapd!"; }
      { assertion = cfg2.countryCode != null;
        message = "The country code is required!"; }
    ];

    services.hostapd.enable = true;
    # don't put passphrase into nix store, please
    services.hostapd.wpa = false;

    # rules for wifi radiation -> required for country_code setting to be used
    services.udev.packages = [ pkgs.crda ];

    systemd.services.hostapd.serviceConfig.wants = [ "freeradius-init.service" ];
    systemd.services.hostapd.serviceConfig.ExecStartPre = [createConfigWithSecret] ++ setFourAddressMode;
    systemd.services.hostapd.serviceConfig.ExecStart = lib.mkForce "${pkgs.hostapd}/bin/hostapd ${secretConfigFile}";
  };
}
