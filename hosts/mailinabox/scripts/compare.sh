#! /usr/bin/env nix-shell
#! nix-shell -i bash -p jq yq
set -xe
nix-build default.nix -o result-all
echo "diff <current on mailinabox> <generated>, for DNS"
#diff -u1 <(yq -S <dns-custom-orig.yaml) <(yq -S <result-all/dns.yaml)
diff -su1 <(ssh mailinabox cat /home/user-data/dns/custom.yaml | yq -S) <(yq -S <result-all/dns.yaml)
echo "diff <current on mailinabox> <generated>, for WWW"
diff -su1 <(ssh mailinabox cat /home/user-data/www/custom.yaml | yq -S) <(yq -S <result-all/www.yaml)

