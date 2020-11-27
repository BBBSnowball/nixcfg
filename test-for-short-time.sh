#!/bin/sh

# We do *not* abort this script in case of errors because that would abort the recovery.
#set -e

if [ -z "$1" ] ; then
  echo "Usage: $0 result-symlink" >&2
  exit 1
elif [ ! -x "$1/bin/switch-to-configuration" ] ; then
  echo "Error: file missing: $1/bin/switch-to-configuration" >&2
  exit 1
fi

cp --remove-destination -dT /run/current-system result.old || exit $?

logger "test-for-short-time.sh: switching to configuration $1 (`realpath "$1"`)..."
timeout 300 "$1/bin/switch-to-configuration" test

echo ""
echo "========================"
echo ""
echo "Configuration has been applied. We will roll back to the old configuration soon. Press ctrl+c to keep the current configuration."
echo ""
echo "If you want to keep the configuration, don't forget to do: $1/bin/switch-to-configuration boot"

for x in `seq 180 -10 10` ; do
  echo -n "$x..  "
  sleep 10
done
echo ""

echo "Rolling back to $(realpath result.old)..."
logger "test-for-short-time.sh: rollback to configuration $PWD/result.old (`realpath result.old`)..."
timeout 300 "./result.old/bin/switch-to-configuration" test

echo "I will reboot in 180 seconds unless you press ctrl+c"

for x in `seq 180 -10 10` ; do
  echo -n "$x..  "
  sleep 10
done
echo ""

echo "Rebooting..."
logger "test-for-short-time.sh: rebooting..."
reboot

sleep 180

echo "Will do hard reboot soon..."
sleep 10
logger "test-for-short-time.sh: hard reboot..."
sleep 1
sync
reboot -f

