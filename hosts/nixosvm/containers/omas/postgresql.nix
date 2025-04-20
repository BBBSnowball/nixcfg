{ lib, pkgs, config, ... }:
{
  services.postgresql = {
    enable = true;

    enableTCPIP = false; # still keeps localhost
    settings.listen_addresses = lib.mkForce "";

    ensureDatabases = [
      "nextcloud"
      "lldap"
      "mediawiki"
    ];
    ensureUsers = let
      userWithDb = name: {
        inherit name;
        ensureDBOwnership = true;
      };
    in [
      (userWithDb "nextcloud")
      (userWithDb "lldap")
      (userWithDb "mediawiki")
    ];
  };

  services.postgresqlBackup.enable = true;
  # put under /var/lib, which is our data partition
  services.postgresqlBackup.location = "/var/lib/backup-postgresql";




  # auto-upgrade database
  # see https://nixos.org/manual/nixos/stable/#module-services-postgres-upgrading
  systemd.services.postgresql =
  with builtins;
  let
    cfg = config.services.postgresql;
    inherit (cfg) package dataDir;
    inherit (package) psqlSchema;
    parentDir = dirOf dataDir;
    # dataDir default is "/var/lib/postgresql/${config.services.postgresql.package.psqlSchema}"
    check = lib.throwIf ((baseNameOf dataDir)!=psqlSchema) "Last path component of services.postgresql.dataDir must be the schema version.";
  in check {
    serviceConfig.TimeoutStartSec = "10min";
    preStart = lib.mkAfter ''
      if [ -e "${dataDir}/.upgrade_done" ] ; then
        echo "PostgreSQL database doesn't need any upgrade."
      elif [ -e "${parentDir}/current-data" -a -e "${parentDir}/current-pkg" ] && [ "$(readlink "${parentDir}/current-data")" != "${psqlSchema}" ] ; then
        echo "Upgrading PostgreSQL from $(readlink "${parentDir}/current-data") to ${psqlSchema}..."

        # initdb has already been done by NixOS' pre-start script
        ( cd "${parentDir}" && ${package}/bin/pg_upgrade \
          --old-datadir "$(readlink -f "${parentDir}/current-data")" --new-datadir "${dataDir}" \
          --old-bindir "${parentDir}/current-pkg/bin" --new-bindir "${package}/bin" )

        touch "${dataDir}/.upgrade_done"

        # don't run initialScript commands
        rm -f "${dataDir}/.first_startup"

        echo "Upgrade done."
      fi
    '';
    postStart = lib.mkAfter ''
      ln -sfT "${psqlSchema}" "${parentDir}/current-data"
      if [ ! -e "${parentDir}/current-pkg" ] || [ "$(realpath "${parentDir}/current-pkg")" != "${package}" ] ; then
        ${pkgs.nix}/bin/nix-store --add-root "${parentDir}/current-pkg" -r "${package}"
      fi
    '';
  };
}
