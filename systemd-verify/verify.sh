#!/usr/bin/env bash
set -e
dir="$(dirname "$0")"
if [ -z "$1" ] ; then
  find -L /etc/systemd/{system,user} -type f \( -name "*.target" -or -name "*.target.d" \) | xargs ls -1 2>/dev/null | xargs systemd-analyze verify --man=0 --generators=0 2>&1|grep -vf "$dir/whitelist"
else
  x="$(realpath "$1")"
  systemd-nspawn --quiet --as-pid2 --pipe --directory "$dir" --bind-ro "/nix/store" --bind-ro "$x:/result" --bind-ro "$x/etc:/etc" --bind-ro "$x/sw:/run/current-system/sw" -E "PATH=/run/current-system/sw/bin:/result/systemd" -- /run/current-system/sw/bin/bash /"$(basename "$0")" 2>&1 \
    | grep -vF '/etc/localtime does not point into /usr/share/zoneinfo/, not updating container timezone.'
fi
