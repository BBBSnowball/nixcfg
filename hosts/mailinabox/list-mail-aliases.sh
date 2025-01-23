#!/bin/sh
CMD=$(cat <<'EOF'
curl -s --user "$(</var/lib/mailinabox/api.key):" http://127.0.0.1:10222/mail/aliases?format=json | jq '.[].aliases | .[] | select(.auto|not) | del(.auto) | del(.address_display) | { (.address|tostring): .|del(.address) }' | jq -sS add | cat
EOF
)
exec ssh mailinabox "$CMD"
