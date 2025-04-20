{ lib, pkgs, config, domain, ports, ... }:
let
  hostName = "wiki.${domain}";
  port = ports.omas-wiki.port;

  # https://github.com/wikimedia/mediawiki-extensions-LDAPProvider/blob/master/docs/mediawiki.ldap.json-sample
  basedn = config.services.lldap.settings.ldap_base_dn;
  ldapDomainsJsonEtc = "/etc/mediawiki/ldapDomains.json";  # without password
  ldapDomainsJsonRun = "/run/phpfpm/domains.json";         # with password for LDAP service user
  ldapDomainsJson = (pkgs.formats.json { }).generate "domains.json" {
    omas = {
      # Configuration for Extension:LDAPProvider
      connection = {
        server = "localhost";
        user = "uid=service_mediawiki,ou=people,${basedn}";
        #options = {
        #  "LDAP_OPT_DEREF" = 1;
        #};
        port = 3890;
        enctype = "clear";
        basedn = basedn;
        groupbasedn = "ou=groups,${basedn}";
        userbasedn = "ou=people,${basedn}";
        searchattribute = "uid";
        # not documented but absolutely required to make it not ask for samaccountname
        # see https://gerrit.wikimedia.org/r/plugins/gitiles/mediawiki/extensions/LDAPProvider/+/refs/heads/REL1_39/extension.json, DefaultAttributes
        userinfoattributes = [
          "cn" "mail" "objectclass" "uid" "memberof"
        ];
        usernameattribute = "uid";
        realnameattribute = "cn";
        emailattribute = "mail";
      };

      authentication.usernameattribute = "uid";

      # Configuration for Extension:LDAPUserInfo
      userinfo.attributes-map = {
        email = "mail";
        realname = "cn";
        nickname = "uid";
      };

      # Configuration for Extension:LDAPAuthorization
      authorization.rules.groups.required = [
        "cn=Omas_intern,ou=groups,${basedn}"
      ];
      
      # Configuration for Extension:LDAPGroups
      groupsync.locally-managed = [
        # all relevant groups are implicitly in this list
      ];
    };
  };
in
{
  services.nginx.virtualHosts.${hostName} = {
    listen = [
      { addr = "0.0.0.0"; inherit port; }
    ];

    # Use explicit domain in redirect so Nginx won't include the internal port.
    locations."= /".extraConfig = lib.mkForce ''
      return 301 https://${hostName}/wiki/;
    '';
  };

  services.mediawiki = {
    enable = true;
    #passwordFile = "/run/credstore/secret_wiki-admin-password";
    passwordFile = "/run/credentials/mediawiki-init.service/password";

    database.type = "postgres";
    database.socket = "/var/run/postgresql";

    webserver = "nginx";
    nginx.hostName = hostName;
    url = "https://${hostName}";
    passwordSender = "noreply@${domain}";
    name = "OmaWiki";

    extraConfig = ''
      # These will show up on the client!
      if (false) {
        # https://www.mediawiki.org/wiki/Manual:How_to_debug
        error_reporting( -1 );
        ini_set( 'display_errors', 1 );

        $wgShowExceptionDetails = true;
        $wgDebugToolbar = true;
        $wgShowDebug = true;
        $wgDevelopmentWarnings = true;
        $wgDebugComments = true;
      }
      if (false) {
        $wgDebugLogFile = "/var/log/mediawiki/debug.log";
      }

      # Disable anonymous editing and account creation.
      $wgGroupPermissions['*']['edit'] = false;
      $wgGroupPermissions['*']['createaccount'] = false;
      $wgGroupPermissions['*']['autocreateaccount'] = true;

      #$GLOBALS['bsgPermissionConfig']['autocreateaccount'] = [ 'type' => 'global', "roles" => [ 'autocreateaccount' ] ];
      #$GLOBALS['bsgGroupRoles']['*']['autocreateaccount'] = true;

      $wgLanguageCode = "de";

      $LDAPProviderDomainConfigs = "${ldapDomainsJsonRun}";

      // copied from https://www.mediawiki.org/wiki/Extension:LDAPAuthentication2

      // If local login is supported as well, then these globals are still needed
      $wgPluggableAuth_EnableLocalLogin = true;
      $LDAPAuthentication2AllowLocalLogin = true;
      $wgPluggableAuth_Config['Anmelden mit "Omas intern" Benutzer'] = [
          'plugin' => 'LDAPAuthentication2',
          'data' => [
              'domain' => 'omas'
          ]
      ];

      $GLOBALS['LDAPSyncAllBlockExecutorUsername'] = 'admin';
      $GLOBALS['LDAPSyncAllExcludedUsernames'] = [ 'admin', 'Admin' ];
      $GLOBALS['LDAPSyncAllExcludedGroups'] = [ 'bot', 'editor', 'bureaucrat', 'sysop' ];
    '';

    extensions = {
      VisualEditor = null;  # null is sufficient because the extension is included

      # https://www.mediawiki.org/wiki/Category:LDAP_extensions
      # https://www.mediawiki.org/wiki/LDAP_hub
      # https://gerrit.wikimedia.org/r/plugins/gitiles/?format=HTML, especially extension.json
      LDAPAuthentication2 = pkgs.fetchzip {
        # https://www.mediawiki.org/wiki/Extension:LDAPAuthentication2
        #url = "https://extdist.wmflabs.org/dist/extensions/LDAPAuthentication2-REL1_43-a98cfcc.tar.gz";
        #hash = "sha256-nkoxYlIUHaVbWcgLujXCLlUxQZfNCl6mvfC/icmsOos=";
        # -> too new
        #url = "https://extdist.wmflabs.org/dist/extensions/LDAPAuthentication2-REL1_42-05febf7.tar.gz";
        #hash = "sha256-OcKE2TUQHxPJnPwl00mS5v4czXbsniagiWHOOOO57EE=";
        url = "https://extdist.wmflabs.org/dist/extensions/LDAPAuthentication2-REL1_39-1adda11.tar.gz";
        hash = "sha256-dSuGGUYtFjzqWMgkycz7j9gzLxSGueX8U6NWyeiT8eo=";
      };
      LDAPProvider = pkgs.fetchzip {
        # https://www.mediawiki.org/wiki/Extension:LDAPProvider
        #url = "https://extdist.wmflabs.org/dist/extensions/LDAPProvider-REL1_43-7febfb9.tar.gz";
        #hash = "sha256-GmJnxGss7ZA0ClVigupJ5z28PmRFHMveBKWWhecI5Tk=";
        url = "https://extdist.wmflabs.org/dist/extensions/LDAPProvider-REL1_39-afc8861.tar.gz";
        hash = "sha256-XLVXJAmvMHZtYSiRFXds0/4jKRtK3dkGAkJJ58Uilfw=";
      };
      LDAPAuthorization = pkgs.fetchzip {
        # https://www.mediawiki.org/wiki/Extension:LDAPAuthorization
        #url = "https://extdist.wmflabs.org/dist/extensions/LDAPAuthorization-REL1_42-81bcaf5.tar.gz";
        #hash = "sha256-SzWqltXymsqS307fllx4HJlLfqynWDCwBL+xzy3vS+0=";
        url = "https://extdist.wmflabs.org/dist/extensions/LDAPAuthorization-REL1_39-4ad821f.tar.gz";
        hash = "sha256-z97RfEy3x/UrEGdzS3Zui9jw21IQV2jN2NT9kId6zAo=";
      };
      LDAPUserInfo = pkgs.fetchzip {
        # https://www.mediawiki.org/wiki/Extension:LDAPUserInfo
        #url = "https://extdist.wmflabs.org/dist/extensions/LDAPUserInfo-REL1_42-f4cd072.tar.gz";
        #hash = "sha256-PmHZopUTv7vbWU53IxFY/gY0kwQbZm0QlPC6DExm2N4=";
        url = "https://extdist.wmflabs.org/dist/extensions/LDAPUserInfo-REL1_39-361a8e5.tar.gz";
        hash = "sha256-HhNzvxPAUFO+uLxGZ7FZOuCoa6ZU0BHTNJ2KnPKqkq0=";
      };
      PluggableAuth = pkgs.fetchzip {
        # https://www.mediawiki.org/wiki/Extension:PluggableAuth
        url = "https://extdist.wmflabs.org/dist/extensions/PluggableAuth-REL1_42-894ee32.tar.gz";
        hash = "sha256-YHUek3pEM9XH2YLLkbfqEbPHMJBEzKGmJEin7eW91/g=";
      };
      LDAPSyncAll = pkgs.fetchzip {
        # https://www.mediawiki.org/wiki/Extension:LDAPSyncAll
        #url = "https://extdist.wmflabs.org/dist/extensions/LDAPSyncAll-REL1_42-2d637e5.tar.gz";
        #hash = "sha256-6xE9Xx7u6i+JuejyrE7WzGWRQGDVIByHmzjKI7vHy0Q=";
        url = "https://extdist.wmflabs.org/dist/extensions/LDAPSyncAll-REL1_39-843fd4b.tar.gz";
        hash = "sha256-bLGv79n1dqUpq2XyMUbJckfo1l/VjyuyfTIsyKRrnpg=";
      };
      LDAPGroups = pkgs.fetchzip {
        # https://www.mediawiki.org/wiki/Extension:LDAPSyncAll
        url = "https://extdist.wmflabs.org/dist/extensions/LDAPGroups-REL1_39-1d5f4e9.tar.gz";
        hash = "sha256-7alH76MrUxHg657b4oAfNHKcia9KnJ+/0DJRKpYMD1s=";
      };


      #FIXME LDAPGroups?
    };
  };

  # allow larger uploads
  services.phpfpm.pools.mediawiki.phpOptions = ''
    upload_max_filesize = 10M
    post_max_size = 15M
  '';

  systemd.services.mediawiki-init.serviceConfig.LoadCredential = [ "password:secret_wiki-admin-password" ];

  systemd.services.phpfpm-mediawiki = {
    serviceConfig = {
      LoadCredential = [ "ldappw:secret_wiki-ldap-password" ];
      #RuntimeDirectory = "phpfpm-mediawiki";
      RuntimeDirectory = "phpfpm";
      # LogsDirectory is not useful for services that drop privileges, see https://github.com/systemd/systemd/issues/28876
      #LogsDirectory = "mediawiki";
      # remove read permissions for the group because PHP workers share the group
      #LogsDirectoryMode = "0700";
    };
    preStart = ''
      umask 077
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "${ldapDomainsJsonEtc}" - \
        <<<"{\"omas\": {\"connection\": {\"pass\": \"$(cat $CREDENTIALS_DIRECTORY/ldappw)\"}}}" \
        >${ldapDomainsJsonRun}
      chown mediawiki ${ldapDomainsJsonRun}
    '';
  };

  environment.etc.${builtins.substring 5 (-1) ldapDomainsJsonEtc}.source = ldapDomainsJson;

  systemd.tmpfiles.rules = [
    # no read permissions for the group because PHP workers share the group
    "d /var/log/mediawiki 0700 mediawiki root 1d"
  ];
}
