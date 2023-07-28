#!/usr/bin/env bash
IFS=,
# intel_backlight,backlight,4711,5%,96000
x=($(brightnessctl -m))
unset IFS
state_file="${XDG_RUNTIME_DIR:-/run/user/$UID}/notify-brightness-id"
id=
[ -e "$state_file" ] && id="$(<"$state_file")" 2>/dev/null
notify-send -e "Brightness: ${x[3]}" "${x[0]}: ${x[2]} / ${x[4]}" -u low -t 800 --hint=int:value:${x[3]%%%} -r "${id:-0}" -p >"$state_file"

