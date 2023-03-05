#! @runtimeShell@ -e

#NOTE This is rather similar to iptables-apply.

export PATH="@path@:$PATH"
CONFIG_DIR=/etc/nixos/secret/by-host/$HOSTNAME/firewall
IP4TABLES_SCRIPT=@script_ipv4@
IP6TABLES_SCRIPT=@script_ipv6@

tmp="$(umask 077; mktemp -d -t firewall-update.XXXXXXXX)"
if [ -z "$tmp" -o ! -d "$tmp" ] ; then
  echo "Couldn't create temporary directory." >&2
  exit 1
fi

cleanup() {
  rm -f "$tmp"/{rules.v?,old.v?,diff}
  rmdir "$tmp"
}
trap cleanup EXIT HUP INT QUIT ILL TRAP ABRT BUS FPE USR1 SEGV USR2 PIPE ALRM TERM     

ruby "$CONFIG_DIR/rules.rb" >"$tmp/rules.v4"
cp "$CONFIG_DIR/rules.v6" "$tmp/rules.v6"

# run test (will abort in case of error due to `set -e`)
( set -x; iptables-restore --test "$tmp/rules.v4" )
( set -x; ip6tables-restore --test "$tmp/rules.v6" )

# save old rules
( set -x; iptables-save >"$tmp/old.v4" )
( set -x; ip6tables-save >"$tmp/old.v6" )

# diff to previous script and current firewall
(
  diff --color=always -u "$IP4TABLES_SCRIPT" "$tmp/rules.v4" || true
  #diff --color=always -u "$tmp/old.v4" "$tmp/rules.v4" || true  # too verbose
  diff --color=always -u "$IP6TABLES_SCRIPT" "$tmp/rules.v6" || true
  #diff --color=always -u "$tmp/old.v6" "$tmp/rules.v6" || true
) >"$tmp/diff"
cnt="$(wc -l "$tmp/diff")"
read cnt _ <<<"$cnt"
if [ "$cnt" == "0" ] ; then
  cat "$tmp/diff"  ;# should be empty but just in case
  echo "There aren't any changes compared to the previous scripts."
elif [ "$cnt" -gt 40 ] ; then
  less -R "$tmp/diff"
else
  cat "$tmp/diff"
fi

echo ""
echo "Please run this script under tmux or screen to avoid restore being blocked by SSH!"  ;# see NOTE below for details
read -p 'Apply these changes? [y/N] ' x
if [ "$x" != "y" ] ; then
  echo "Aborted by user."
  exit 255
fi

# We do *not* abort this script in case of errors because that would abort the recovery.
set +e

#NOTE We assume that this script is run under tmux or screen so any output produced will
#     not be harmful, i.e. it will not happen that we produce some output and then we will
#     hang (and not restore) because SSH cannot send that output to the client anymore.

( set -x; iptables-restore "$tmp/rules.v4" )
( set -x; ip6tables-restore "$tmp/rules.v6" )

read -t 30 -p "Keep these changes for now? Automatic revert in 30 sec. [y/N] " x || true
echo ""  ;# newline after prompt in case of timeout
if [ "$x" != "y" ] ; then
  echo "Aborted by user."
  ( set -x; iptables-restore "$tmp/old.v4" )
  ( set -x; ip6tables-restore "$tmp/old.v6" )
  exit 255
fi

read -p "Keep these changes permanently ($IP4TABLES_SCRIPT) ? [Y/n] " x || true
if [ "$x" == "y" -o "$x" == "" ] ; then
  ( set -x; cp "$tmp/rules.v4" "$IP4TABLES_SCRIPT" )
  ( set -x; cp "$tmp/rules.v6" "$IP6TABLES_SCRIPT" )
else
  echo "Not changing $IP4TABLES_SCRIPT."
fi

