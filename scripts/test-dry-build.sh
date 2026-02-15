#!/bin/sh -e

flake=.

if [ -n "$1" ] ; then
    hosts=("$@")
else
    hosts=(
        nixosvm
        c3pbvm
        sonline0
        hetzner-gos
        hetzner-temp
        fw
        bettina-home
        ug1
    )
fi

for hostname in "${hosts[@]}" ; do
    echo ""
    echo ""
    echo -e "\e[1m== $hostname ==\e[0m"
    echo ""

    #(set -x; nixos-rebuild --flake "$flake#$hostname" dry-build -L --override-input private path:./example-private-dir )

    # We only want to test whether we can evaluate the config for that host,
    # so we don't need the long list of paths that would be built (which dry-build would print).
    # Thus, we only evaluate the derivation path.
    (
        set -x
        time nix --experimental-features 'nix-command flakes' --log-format bar-with-logs \
            eval --override-input private path:./example-private-dir \
            --raw "$flake#nixosConfigurations.$hostname.config.system.build.toplevel.drvPath"
    )
done
