#! /usr/bin/env nix-shell
#! nix-shell -i bash -p jq yq
set -xe
nix-build dns-custom.nix -o result-dns
nix-build www-custom.nix -o result-www
echo "diff <current on mailinabox> <generated>, for DNS"
#diff -u1 <(yq -S <dns-custom-orig.yaml) <(yq -S <result-dns)
diff -su1 <(ssh mailinabox cat /home/user-data/dns/custom.yaml | yq -S) <(yq -S <result-dns)
echo "diff <current on mailinabox> <generated>, for WWW"
diff -su1 <(ssh mailinabox cat /home/user-data/www/custom.yaml | yq -S) <(yq -S <result-www)

