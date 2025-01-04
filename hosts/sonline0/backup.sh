#! /usr/bin/env bash

# e.g. collection-status, list-current-files

LOCAL_DIR=/

source /etc/nixos/secret/by-host/sonline0/backup_env

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
    backupArgs+=(--concurrency 2)
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
    # full or incremental
    shift
    CMD=("$@" $LOCAL_DIR $target_url)
    ;;
  full|incr)
    CMD=("$@" $LOCAL_DIR $target_url)
    ;;
  verify)
    CMD=("$@" $target_url $LOCAL_DIR)
    ;;
  cron)
    exec 1>>"$logfile" 2>&1
    date
    if pgrep duplicity >/dev/null ; then
      echo "Duplicity is already/still running."
      exit 0
    fi
    echo "Starting backup..."
    #NOTE "--force" is required for remove-all-but-n-full because default behavior is to list instead of remove.
    "$0" backup --backend-retry-delay 300 --full-if-older-than 2W \
      && "$0" remove-all-but-n-full 5 --force
    exit $?
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

#NOTE Things to exclude if we ever do a full backup of root:
#  /var/cache     # package cache, etc.
#  /root/.cache   # duplicity cache

# don't do --exclude-other-filesystems anymore because of /var/vms
FTP_PASSWORD="$FTP_PASSWORD" PASSPHRASE="$PASSPHRASE" \
	duplicity \
	--encrypt-key $encrypt_for \
	--encrypt-sign-key $our_key \
        "${backupArgs[@]}" \
        $extra_args \
	"${CMD[@]}"

