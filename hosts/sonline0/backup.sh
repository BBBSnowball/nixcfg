#! /usr/bin/env bash

# e.g. collection-status, list-current-files

LOCAL_DIR=/

source /etc/nixos/secret/by-host/sonline0/backup_env

#NOTE Things to exclude if we ever do a full backup of root:
#  /var/cache     # package cache, etc.
#  /root/.cache   # duplicity cache

# don't do --exclude-other-filesystems anymore because of /var/vms
backupArgs=(
	--exclude /var/cache \
	--exclude /root/.cache \
	--exclude /proc \
	--exclude /sys \
	--exclude /dev \
	--exclude /run \
	--exclude /tmp \
	--exclude /var/tmp \
	--exclude /nix/store \
	--exclude /var/vms/nixos-minimal-*-linux.iso \
	--exclude "/var/vms/*.bak*" \
	--exclude /var/vms/nixos-nix.img \
	--exclude /var/vms/nixos-swap.img \
	--exclude /var/vms/c3pb-nix.img \
)

case "${target:-}" in
  dedibackup)
    logfile=/var/log/duplicity-backup-to-ftp.log
    backupArgs+=(
  	--ftp-passive \
  	--volsize 1000 \
    )
    ;;
  hetzner)
    logfile=/var/log/duplicity-backup-to-hetzner.log
    target_url="$target_url2"
    # Use IPv4 because that turned out to still be more stable than IPv6. Oh, well.
    # -> Actually, this won't affect the internal SSH backend, so we use LD_PRELOAD. See backup.nix.
    backupArgs+=(--concurrency 2 --ssh-options=-4)
    ;;
  *)
    echo "Invalid \$target!" >&2
    exit 1
    ;;
esac

case "$1" in
  ""|help|--help)
    echo "Try one of \`backup --progress -vi\`, verify, collection-status, list-current-files" 2>&1
    exit 1
    ;;
  backup)
    # full or incremental, chosen by duplicity
    #shift
    CMD=("$@" $LOCAL_DIR $target_url)
    ;;
  full|incr)
    CMD=("$@" $LOCAL_DIR $target_url)
    ;;
  verify)
    CMD=("$@" $target_url $LOCAL_DIR)
    ;;
  cron)
    exec 3>&1 4>&2 1>>"$logfile" 2>&1
    date
    if pgrep duplicity >/dev/null ; then
      #NOTE Duplicity also has its own check but that won't print any reason to syslog,
      #     i.e. it would fail and send an email without any helpful context.
      echo "Duplicity is already/still running."
      echo "Duplicity is already/still running." >&4
      exit 1
    fi
    echo "Starting backup..."
    echo "Starting backup..." >&3
    set -e
    "$0" backup --backend-retry-delay 300 --full-if-older-than 2W
    echo "Removing old backups..."
    echo "Removing old backups..." >&3
    #NOTE "--force" is required for remove-all-but-n-full because default behavior is to list instead of remove.
    "$0" remove-all-but-n-full 5 --force
    echo "done."
    echo "Backup is finished." >&3
    exit 0
    ;;
  *)
    CMD=("$@" $target_url)
    backupArgs=()
    ;;
esac

#NOTE online.net has a quite low limit of 1000 files on the FTP server even if
#     I upgrade to the payed plan. With the default --volsize of 200 MB, we would
#     run into that limit long before we get to the size limit of 750 GB.
#
#     In addition, there are some smaller files (e.g. signatures and small increments)
#     so we should choose something larger than maxsize/maxfiles. At the moment, we
#     have volsize=200 and 93 of 795 files (12%) are smaller than 190 MB.
#     So, a good volsize would be maxsize/(0.8*maxfiles) = 938 MB.
#NOTE online.net requires passive FTP.

#export FTP_PASSWORD  # duplicity complains if we set this
export BACKEND_PASSWORD="$FTP_PASSWORD"
export PASSPHRASE

exec duplicity \
	--encrypt-key $encrypt_for \
	--encrypt-sign-key $our_key \
        "${backupArgs[@]}" \
        $extra_args \
	"${CMD[@]}"

