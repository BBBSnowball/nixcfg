#!/usr/bin/env bash
set -e
dir="$(dirname "$0")"
#find -L result/etc/systemd/{system,user} -type f ! -name "*.conf" ! -name "*@.*" -exec systemd-analyze verify --man=0 --generators=0 {} \+ 2>&1|grep -vf "$dir/whitelist"
systemd-analyze verify --man=0 --generators=0 $1/etc/systemd/system/multi-user.target.wants/* 2>&1 | grep -vf "$dir/whitelist"
