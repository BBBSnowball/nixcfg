#!/usr/bin/env bash
set -eo pipefail
PATH="$PATH":@jq@/bin
export sink="$(pactl get-default-sink)"
x="$(
  pactl -f json list sinks | jq -r '.[] | select(.name == $ENV["sink"]) | (( .volume | map_values(.value_percent) ) + ( { base_volume: .base_volume.value_percent } ) ) | to_entries | .[] | (.key + ": " + .value)'
)"
# -> list of "sink name: xx%"
IFS=$'\n'
lines=($x)
unset IFS
first="${lines[0]##*: }"
first="${first%%%}"

y="$(pactl get-source-mute @DEFAULT_SOURCE@)"
if [ "$y" != "Mute: no" ] ; then
  x="Input: $y"$'\n'"$x"
fi
y="$(pactl get-sink-mute @DEFAULT_SINK@)"
if [ "$y" != "Mute: no" ] ; then
  x="Output: $y"$'\n'"$x"
fi

state_file="${XDG_RUNTIME_DIR:-/run/user/$UID}/notify-volume-id"
id=
[ -e "$state_file" ] && id="$(<"$state_file")" 2>/dev/null
notify-send -e "Volume" "$x" -u low -t 800 --hint=int:value:"$first" -r "${id:-0}" -p >"$state_file"

