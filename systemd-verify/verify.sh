#!/usr/bin/env bash
set -e
dir="$(dirname "$0")"
#find -L "$1"/etc/systemd/{system,user} -type f ! -name "*.conf" ! -name "*@.*" -exec systemd-analyze verify --man=0 --generators=0 {} \+ 2>&1|grep -vf "$dir/whitelist"
find -L "$1"/etc/systemd/{system,user} -type f \( -name "*.target" -or -name "*.target.d" \) | xargs ls -1 2>/dev/null | xargs systemd-analyze verify --man=0 --generators=0 2>&1|grep -vf "$dir/whitelist"
#systemd-analyze verify --man=0 --generators=0 \
#  $1/etc/systemd/system/*.target.wants/* \
#  $1/etc/systemd/system/*.target \
#  $1/etc/systemd/user/*.target.wants/* \
#  $1/etc/systemd/user/*.target \
#  2>&1 | grep -vf "$dir/whitelist"
