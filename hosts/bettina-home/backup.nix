{ lib, pkgs, privateForHost, ... }:
#NOTE Repository has to be created with `borgmatic init --encryption repokey` after this config is applied.
#     Then, maybe test with `borgmatic create --verbosity 1 --list --stats`.
{
  services.borgmatic = {
    enable = true;
    settings = {
      archive_name_format = "main-{now}";
      match_archives = "main-*";

      source_directories = [
        "/etc"
        "/home"
        "/root"
        "/srv"
        "/var"
      ];
      exclude_patterns = [
        "/var/lib/libvirt/images/haos_ova-*.qcow2"
        "/var/lib/omada-controller/bin"  # copy of files from Nix store
        "/var/lib/omada-controller/lib"  # ^^
        "/var/lib/omada-controller/data/db"  # info should also be in autobackup
        "/var/lib/private/omada-controller/bin"
        "/var/lib/private/omada-controller/lib"
        "/var/lib/private/omada-controller/data/db"
        "/var/log/journal"
        "/var/backup/vaultwarden/icon_cache"
        "/root/.cache/nix"
        "/var/lib/bitwarden_rs/db.*"
      ];

      repositories = [
        { label = "hetzner"; path = "ssh://hetzner-box-bettina-home/./bettina-home"; }
      ];
      extra_borg_options.init = "--storage-quota 50G";

      one_file_system = true;

      #encryption_passcommand = "cat $CREDENTIALS_DIRECTORY/password";
      # -> service runs as root anyway and this should also work in a root shell outside of the service.
      encryption_passcommand = "cat /etc/nixos/secret/by-host/bettina-home/backuppw";

      keep_daily = 7;
      keep_weekly = 30;
      keep_monthly = 24;

      # The builtin database dumper doesn't support changing to the right user
      # and it is using `.dump` rather than `.backup`. The NixOS module for
      # vaultwarden already makes a backup with `.backup` and that should be
      # consistent. borgmatic uses a named pipe rather than making a physical
      # copy, which is quite nice, but the file shouldn't be large enough for
      # that to matter.
      #sqlite_databases = [
      #  { name = "vaultwarden"; path = "/var/lib/bitwarden_rs/db.sqlite3"; }
      #];

      before_backup = let
        backupSqlite = pkgs.writeShellScript "backup-sqlite" ''
          set -e
          umask 077
          t=$(mktemp -d)
          ( cd "$t" && set -x && ${pkgs.sqlite}/bin/sqlite3 "$1" ".backup db.sqlite3" )
          cat <"$t/db.sqlite3" >&3
          rm -rf "$t"
        '';
      in [ (pkgs.writeShellScript "before-backup" ''
        set -eo pipefail

        # borgmatic_source_directory is ~/.borgmatic so we also store our files there.
        d=/root/.borgmatic/additional_files
        rm -rf $d
        umask 077
        mkdir -p $d

        # HomeAssistant is supposed to be able to backup itself but none of the
        # existing borgbackup addons were working for us. This is looking quite
        # good (if you learn to work around its small bugs) but HA refuses to
        # let it create any backups although it does have `hassio_role: backup`:
        # https://github.com/bmanojlovic/home-assistant-borg-backup/blob/master/run.sh
        # -> We copy the relevant parts and let borgmatic do the actual backup
        #    (which also means that HA doesn't need permissions for the borg repo)
        # `ssh ha-ssh` connects to port 22 of HA, i.e. to the SSH addon.
        #NOTE The following lines are based on the run.sh file,
        #     which doesn't have any license that I can find.
        time="$(date +'%Y-%m-%d--%H:%M')"
        json="$(set -x; ssh ha-ssh ha backups new --uncompressed --name "borgmatic-$time" --raw-json)"
        export PATH="${pkgs.jq}/bin:$PATH"
        ok="$(jq -r .result <<<"$json")"
        if [ "$ok" != "ok" ] ; then
          echo "ERROR: Couldn't get backup from HomeAssistant: $json" >&2
        else
          slug="$(jq -r .data.slug <<<"$json")"
          ( set -x
            scp ha-ssh:"/backup/$slug.tar" $d/homeassistant.tar \
            && ssh ha-ssh rm "/backup/$slug.tar" )
        fi

        # Backup SQLite database
        # This is different from what borgmatic would do on its own:
        # - It uses the correct user to access the database so locking and journal
        #   should work as expected and we don't have any attack surface for privilege
        #   escalation via the database.
        # - It uses a temporary file rather than a named pipe, which is less elegant
        #   (needs temp space, might wear SSD if Linux decides to commit it to disk).
        #   The upside is that we can forgo the read-special setting for borg.
        #   (And we would have a hard time handling the necessary subprocesses between
        #    our shell hooks, which we could solve by making this a proper borgmatic hook.)
        ( set -x
          ${pkgs.su}/bin/su vaultwarden -s ${pkgs.bash}/bin/bash -c '${backupSqlite} /var/lib/bitwarden_rs/db.sqlite3' 3>$d/vaultwarden.sqlite3
        )

        # The journal is rather large and it is a database (i.e. naive backup might be
        # inconsistent) so we rather save its last lines as a text file.
        ( set -x; journalctl --since -2d -n 20000 >$d/journal.txt )
      '') ];
      after_backup = [ (pkgs.writeShellScript "after-backup" ''
        ( set -x; rm -rf /root/.borgmatic/additional_files )
      '') ];
    };
  };

  systemd.services.borgmatic.path = [ pkgs.openssh ];
  systemd.services.borgmatic.serviceConfig = {
    # allow setgid and setuid because we want to change to the right user when backing up databases
    CapabilityBoundingSet   = lib.mkForce "CAP_SETGID CAP_SETUID CAP_DAC_READ_SEARCH CAP_NET_RAW";
  };

  # We should usually use the borgmatic tool but having borg could be useful,
  # e.g. for `borg help patterns` and man pages.
  # -> `borgmatic borg ...` is usually the better option.
  environment.systemPackages = [ pkgs.borgbackup ];


  systemd.services."notify-by-mail@" = let
    script = pkgs.writeShellScript "notify-by-mail" ''
      (
        echo "Subject: [bettina-home] service $1 failed"
        echo ""
        systemctl status "$1"
      ) | /run/wrappers/bin/sendmail ${privateForHost.adminEmail}
    '';
  in {
    description = "send an email when a service fails";

    serviceConfig.Type = "oneshot";
    serviceConfig.ExecStart = "${script} %i";
  };

  systemd.services.borgmatic.unitConfig.OnFailure = "notify-by-mail@%n";
}
