#!/bin/sh

set -e

if [ -z "$1" ] ; then
  echo "Usage: $0 result-symlink" >&2
  exit 1
elif [ ! -x "$1/bin/switch-to-configuration" ] ; then
  echo "Error: file missing: $1/bin/switch-to-configuration" >&2
  exit 1
fi

cp --remove-destination -dT /run/current-system result.old

"$1/bin/switch-to-configuration" test || true

echo ""
echo "========================"
echo ""
echo "Configuration has been applied. We will roll back to the old configuration in 30 seconds. Press ctrl+c to keep the current configuration."
echo ""
echo "If you want to keep the configuration, don't forget to do: $1/bin/switch-to-configuration boot"

for x in 60 50 40 30 20 10 ; do
  echo -n "$x..  "
  sleep 10
done
echo ""

echo "Rolling back to $(realpath result.old)..."
if ! timeout 300 "./result.old/bin/switch-to-configuration" test ; then
  echo "Rollback has failed. Trying reboot."
  reboot
fi

