#/usr/bin/bash
set -e

read cmd name value x <<<"$SSH_ORIGINAL_COMMAND"

if [ -n "$x" -o -z "$value" ] ; then
  echo "not the right number of arguments in \$SSH_ORIGINAL_COMMAND" >&2
  exit 200
fi

# client adds a trailing dot (which is correct) but mailinabox API doesn't like that
name="${name%.}"

case "$name" in
  bettina-home-acme.domain-without-dnssec)
    # lego will resolve the CNAME so we will get this one instead of the others.
    ;;
  *)
    echo "domain not allowed: $name" >&2
    exit 200
    ;;
esac

value2="${value//[^-a-zA-Z0-9_+=]/}"
if [ "$value" != "$value2" ] ; then
  echo "value contains forbidden characters: $value" >&2
  exit 200
fi

# This is too slow because mailinabox will set TTL to 1 day.
if false ; then
  case "$cmd" in
    present)
      echo "adding record..."
      curl -X PUT -s -d "$value2" --user $(</var/lib/mailinabox/api.key): "http://127.0.0.1:10222/dns/custom/$name/txt"
      ;;
    cleanup)
      echo "removing records..."
      curl -X DELETE -s --user $(</var/lib/mailinabox/api.key): "http://127.0.0.1:10222/dns/custom/$name/txt"
      ;;
    *)
      echo "invalid command" >&2
      exit 200
      ;;
  esac
else
  # We redirect all challanges to a special zone that we control.
  # It has to be on a domain that doesn't support DNSSEC because I don't want to sign it here.
  ttl=60
  if [ "$cmd" == "cleanup" ] ; then
    ttl=5
    value2=""
  fi
  cat >/etc/nsd/zones/$name.txt <<EOF
\$ORIGIN $name.
\$TTL $ttl

@ IN SOA ns1.mail.domain-without-dnssec. hostmaster.the-other-domain. (
           $(date '+%s')     ; serial number
           30     ; Refresh (secondary nameserver update interval)
           15     ; Retry (when refresh fails, how often to try again, should be lower than the refresh)
           60     ; Expire (when refresh fails, how long secondary nameserver will keep records around anyway)
           30     ; Negative TTL (how long negative responses are cached)
           )
EOF
  case "$cmd" in
    present)
      echo "adding record, $name -> \"$value2\"..."
      echo "@       IN      TXT     \"$value2\"" >>/etc/nsd/zones/$name.txt
      ;;
    cleanup)
      echo "removing records..."
      ;;
    *)
      echo "invalid command" >&2
      exit 200
      ;;
  esac
  killall -HUP /usr/sbin/nsd
fi
