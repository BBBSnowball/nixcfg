#!/usr/bin/env nix-shell
#!nix-shell -i bash -p dtc
set -xe
cd "`dirname "$0"`"
dtc -I dts -O dtb -@ -o dt-overlay--use-fan.dtbo dt-overlay--use-fan.dts
dtc -I dtb -O dts dt-overlay--use-fan.dtbo -f
fdtoverlay -o result -i /run/current-system/dtbs/rockchip/rk3399-rockpro64.dtb dt-overlay--use-fan.dtbo
dtc -I dtb -O dts result -o result.dts
$EDITOR result.dts
