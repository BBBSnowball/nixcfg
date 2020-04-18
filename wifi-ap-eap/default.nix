{ config, pkgs, lib, ... }:
{
  options.services.wifi-ap-eap = with lib; let
     cfg = config.services.wifi-ap-eap;
  in {
    enable = mkOption {
      default = false;
      description = ''
        Enable wifi access point using WPA-EAP with hostapd and FreeRadius.

        Use services.hostapd to configure hostapd, e.g. interface and ssid.

        You should usually configure a DHCP server or bridge the wifi to an
        ethernet segment with a DHCP server.
      '';
    };

    wifiFourAddressMode = mkOption {
      default = null;
      example = true;
      description = ''
        Enable 4-address mode if true. This is often required when bridging packets.
        This is equivalent to: iw dev <devname> 4addr on
        Valid values are true (turn on), false (turn off) or null (don't change).

        The wifi frames usually contain the MAC addresses of the wifi interfaces
        and one additional MAC in case the source or destination is not one of
        the wifi interfaces. Therefore, you cannot send frames that have a
        different source *and* destination MAC. Enable 4-address mode to avoid
        this restriction.

        This will often fail in client mode because many APs don't accept
        4-address frames. As we are the AP, this shouldn't cause any problems.

        see http://nullroute.eu.org/~grawity/journal-2011.html#post:20110826
      '';
    };

    # This should be in hostapd section but it will only be active if wifi-ap-eap is enabled
    # so we put it here to avoid confusion.
    countryCode = with lib; mkOption {
      example = "US";
      type = types.str;
      description = "Regulatory domain, used to set wifi parameters, e.g. allowed channels and tx power.";
    };

    serverName = mkOption {
      default = "my.wifi.example.com";
      type = types.str;
      description = "Name used for hostapd's nas_interface.";
    };

    secretsDir = mkOption {
      default = "/etc/wifi-ap-eap";
      type = types.str;
      description = "Directory for storing keys and shared secret for radius.";
    };

    serverCertValidDays = mkOption {
      default = 60;
      example = 3650;
      type = types.int;
      description = "Server certificate will expire after that many days.";
    };
    clientCertValidDays = mkOption {
      default = 60;
      example = 3650;
      type = types.int;
      description = "Client certificates will expire after that many days.";
    };
    countryName = mkOption {
      default = cfg.countryCode;
      example = "FR";
      type = types.str;
      description = "Country name for certificate.";
    };
    stateOrProvinceName = mkOption {
      default = "Radius";
      type = types.str;
      description = "Used for certificate.";
    };
    localityName = mkOption {
      default = "Somewhere";
      type = types.str;
      description = "Used for certificate.";
    };
    organizationName = mkOption {
      default = "Example Inc.";
      type = types.str;
      description = "Used for certificate.";
    };
    emailAddress = mkOption {
      default = "admin@" + cfg.commonNameInner;
      example = "admin@example.org";
      type = types.str;
      description = "Used for certificate.";
    };
    commonNameServer = mkOption {
      default = "server." + cfg.serverName;
      example = "Example Server Certificate";
      type = types.str;
      description = "Used for certificate.";
    };
    commonNameInner = mkOption {
      default = cfg.serverName;
      example = "Example Server Certificate";
      type = types.str;
      description = "Used for certificate.";
    };
    commonNameCA = mkOption {
      default = "ca." + cfg.serverName;
      example = "Example Server Certificate";
      type = types.str;
      description = "Used for certificate.";
    };
  };

  imports = [
    ./hostapd.nix
    ./radius.nix
  ];
}
