#! @runtimeShell@ -e

#NOTE This is rather similar to iptables-apply.

# Most tools are taken from a fixed path but systemd-nspawn comes from $PATH because it should match
# the systemd version of the current system.
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
  set +e
  rm -rf "$tmp/tmp-container-root"
  rm -f "$tmp"/{*.v?,diff,ok}
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

# Make some dummy rules (which only set counters) so our temporary container will
# not omit the nat table for IPv6.
echo "*nat" >"$tmp/dummy.v6"
echo ":PREROUTING ACCEPT [42:42]" >>"$tmp/dummy.v6"
echo "COMMIT" >>"$tmp/dummy.v6"

# apply rules in temporary container so we can compare them to the current state
mkdir "$tmp/tmp-container-root"
systemd-nspawn --private-network --ephemeral -D "$tmp/tmp-container-root" --bind-ro /nix/store --bind "$tmp" --chdir "$tmp" \
  -E "PATH=@path@" \
  @runtimeShell@ -c \
  "set -x; iptables-restore rules.v4 && iptables-save >new.v4 && ip6tables-restore dummy.v6 && ip6tables-restore rules.v6 && ip6tables-save >new.v6 && touch ok"
if [ ! -e "$tmp/ok" ] ; then
  echo "Something went wrong in our temporary container. See above." >&2
  exit 1
fi

# remove counters and dates so they won't swamp our diff
cp "$tmp/old.v4" "$tmp/old2.v4"
cp "$tmp/old.v6" "$tmp/old2.v6"
sed -i 's/^\(:.*\) \[[0-9:]*\]$/\1/; s/^\(#.* on \).*/\1<date>/' "$tmp"/{old2.v4,old2.v6,new.v4,new.v6}

# diff to previous script and current firewall
(
  echo "=== changes between old scripts and new scripts ==="
  diff --color=always -u "$IP4TABLES_SCRIPT" "$tmp/rules.v4" && echo "IPv4 is unchanged." || true
  diff --color=always -u "$IP6TABLES_SCRIPT" "$tmp/rules.v6" && echo "IPv6 is unchanged." || true
  echo "=== changes between current firewall and new rules (as applied in a temporary container) ==="
  diff --color=always -u "$tmp/old2.v4" "$tmp/new.v4" && echo "IPv4 is unchanged." || true
  diff --color=always -u "$tmp/old2.v6" "$tmp/new.v6" && echo "IPv6 is unchanged." || true
) >"$tmp/diff"
cnt="$(wc -l "$tmp/diff")"
read cnt _ <<<"$cnt"
if [ "$cnt" -gt 40 ] ; then
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

# apply the new firewall rules
( set -x; iptables-restore "$tmp/rules.v4" )
( set -x; ip6tables-restore "$tmp/rules.v6" )

# Connct to ourselves via a remote jump host.
# - The remote host must have our SSH key added with these options: restrict,permitopen="our-ip:*",port-forwarding ssh-rsa ...
# - Our host must have the SSH key added with a forced command: restrict,command="echo ok" ssh-rsa ...
# - (It could be without any restrictions in both cases but we don't want that for a test key.)
# - ssh_check_config should look like this:
#   Host check
#     HostName ourselves
#     Port 22
#     User user
#     ProxyJump user@remote_host
#   Host *
#     # This must be here rather than on the command line because we also need it for the ProxyJump.
#     IdentityFile /etc/nixos/secret/by-host/sonline0/firewall
( set -x; timeout 5 ssh -F "$CONFIG_DIR/ssh_check_config" check echo ok )

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

