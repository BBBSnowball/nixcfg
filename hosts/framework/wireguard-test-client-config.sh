#! /usr/bin/env nix-shell
#! nix-shell -i bash -p wireguard-tools jq iproute2 systemd qrencode

ip="$(networkctl --json=pretty | jq -r ".Interfaces | .[] | select(.Type == \"wlan\") | .Addresses[] | select(.ScopeString == \"global\" and .Family == 2) | .Address | join(\".\")")"

config="$(
  echo "[Interface]"
  echo "PrivateKey = $(cat /etc/nixos/secret_local/wireguard-test-pixel6a.priv)"
  #echo "ListenPort = ..."
  echo "Address = 10.100.0.2/32"
  echo ""
  echo "[Peer]"
  echo "PublicKey = $(wg pubkey < /etc/nixos/secret_local/wireguard-test-fw.priv)"
  echo "PresharedKey = $(cat /etc/nixos/secret_local/wireguard-test-pixel6a.psk)"
  echo "Endpoint = $ip:51820"
  echo "AllowedIPs = 10.100.0.0/24"
)"

echo ""
echo "$config"
echo ""

qrencode -t ANSI <<<"$config"

