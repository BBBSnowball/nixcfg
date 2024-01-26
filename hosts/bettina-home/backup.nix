{ pkgs, ... }:
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
    };
  };

  # We should usually use the borgmatic tool but having borg could be useful,
  # e.g. for `borg help patterns`.
  environment.systemPackages = [ pkgs.borgbackup ];

  #FIXME extract some info before backup
  # - last lines of journal
  # - HA backup, similar to run.sh in https://github.com/bmanojlovic/home-assistant-borg-backup
  #   (ssh ha-ssh ha backups new ... --uncompressed && scp /backups/$slug.tar ...)
}
