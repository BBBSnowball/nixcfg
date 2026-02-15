#!@runtimeShell@
set -e

dir="@dir@"
firewallRules4Path="@dir@/rules.rb"
firewallRules6Path="@dir@/rules.v6"

t="$(mktemp -dt iptables-state.XXXXXXXXXX)"
cleanup() {
  rm -f "$t"/ip[46][ab] "$t/rules.v4"
  rmdir "$t"
}
trap cleanup EXIT

iptables-save -f "$t/ip4a"
ip6tables-save -f "$t/ip6a"

if ! ( set -x; ruby ${firewallRules4Path} >"$t/rules.v4" && iptables-restore <"$t/rules.v4" && ip6tables-restore <${firewallRules6Path} ) ; then
  echo "ERROR: Rules couldn't be applied (see above)!"
  rm -f "$t1" "$t2"
  exit 1
fi

iptables-save -f "$t/ip4b"
ip6tables-save -f "$t/ip6b"

# remove counters
sed -i 's/^\(:[^\[]*\)\[[0-9:]*\]$/\1[..]/; /^# \(Generated\|Completed\) / s/ on .*/ on .../' "$t"/ip[46][ab]

echo "== diff state for v4 =="
echo ""
diff -u1 --color "$t"/ip4{a,b} || echo "-none-"

echo ""
echo "== diff state for v6 =="
echo ""
diff -u1 --color "$t"/ip6{a,b} || echo "-none-"

echo ""
echo "== diff rules for v4 =="
echo ""
diff -u1 --color /etc/iptables/rules.v4 "$t/rules.v4" || echo "-none-"

echo ""
echo "== diff rules for v6 =="
echo ""
diff -u1 --color /etc/iptables/rules.v6 ${firewallRules6Path} || echo "-none-"

read -p "Apply firewall rules for use during boot? [y/N] " answer
if [ "$answer" == "y" ] ; then
  cp "$t/rules.v4" /etc/iptables/rules.v4
  cp ${firewallRules6Path} /etc/iptables/rules.v6
else
  echo "Aborted by user."
  exit 1
fi

