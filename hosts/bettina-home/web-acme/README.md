`web.nix` will use SSH to try and set the DNS records for ACME. DNS is provided
by mailinabox in our case so we are a bit limited w.r.t. how we can add records
with short TTL.

- lego will call `$dnsScript`, which forwards the request via SSH.
- mailinabox host, `~/.ssh/authorized_keys`: `restrict,command="/root/acme-dns-update-for-bettina-home.sh" ssh-rsa ...`
- DNS records:
    - `bettina-home.domain`: `A` record for any of the IPs (optional)
    - `lokal.bettina-home.domain` and `*.lokal.bettina-home.domain`: `A` record to local IP
    - `vpn.bettina-home.domain` and `*.vpn.bettina-home.domain`: `A` record to VPN IP
    - `_acme-challenge.bettina-home.domain`: `CNAME bettina-home-acme.domain-without-dnssec.`
- configure dedicated zone file for ACME challenges (created by the script above): `/etc/nsd.conf.d/zones2.conf`:
    ```
    zone:
        name: bettina-home-acme.domain-without-dnssec
        zonefile: bettina-home-acme.domain-without-dnssec.txt
    ```
- set DNS server to 9.9.9.9 if you ISP filters DNS results with local IPs
