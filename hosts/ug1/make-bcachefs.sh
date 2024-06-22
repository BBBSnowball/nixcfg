set -xe

if true ; then
  lvcreate --size=4T --name hdd1 hdd /dev/disk/by-id/lvm-pv-uuid-ij2zcL-4x2n-U4Cb-AdO5-9IuP-iOmw-tCK9mF
  lvcreate --size=4T --name hdd2 hdd /dev/disk/by-id/lvm-pv-uuid-tikxrx-oRXA-PJGV-ames-Glzz-cORa-IHgrj1
  lvcreate --size=4T --name hdd3 hdd /dev/disk/by-id/lvm-pv-uuid-a4NbG7-GvbD-uq9D-7qLc-TN6R-z0Qv-Papt5f
  lvcreate --size=1T --name ssd1 ssd /dev/disk/by-id/lvm-pv-uuid-v5614q-O4aC-E5vU-mhF1-XyKe-cicf-xosX9S
  lvcreate --size=1T --name ssd2 ssd /dev/disk/by-id/lvm-pv-uuid-NIbvgG-ViMl-hKe3-iUeI-NWnb-QJ3v-ygscJz
  bcachefs format \
      --label=hdd.hdd1 /dev/hdd/hdd1 \
      --label=hdd.hdd2 /dev/hdd/hdd2 \
      --label=hdd.hdd3 /dev/hdd/hdd3 \
      --discard \
      --label=ssd.ssd1 /dev/ssd/ssd1 \
      --label=ssd.ssd2 /dev/ssd/ssd2 \
      --foreground_target=ssd \
      --promote_target=ssd \
      --background_target=hdd \
      --replicas=2 \
      --prjquota
fi

if true ; then
  # use `pvdisplay -m` to see where the existing LVs are
  lvcreate --size=4T --name hdd1e hdd /dev/disk/by-id/lvm-pv-uuid-ij2zcL-4x2n-U4Cb-AdO5-9IuP-iOmw-tCK9mF
  lvcreate --size=4T --name hdd2e hdd /dev/disk/by-id/lvm-pv-uuid-tikxrx-oRXA-PJGV-ames-Glzz-cORa-IHgrj1
  lvcreate --size=4T --name hdd3e hdd /dev/disk/by-id/lvm-pv-uuid-a4NbG7-GvbD-uq9D-7qLc-TN6R-z0Qv-Papt5f
  lvcreate --size=1T --name ssd1e ssd /dev/disk/by-id/lvm-pv-uuid-v5614q-O4aC-E5vU-mhF1-XyKe-cicf-xosX9S
  lvcreate --size=1T --name ssd2e ssd /dev/disk/by-id/lvm-pv-uuid-NIbvgG-ViMl-hKe3-iUeI-NWnb-QJ3v-ygscJz
  key=/etc/nixos/secret_local/bcachefs_key
  if [ ! -e $key ] ; then
    pwgen 60 1 >$key.new
    mv -n $key.new $key
  fi
  # `bcachefs unlock` has a `-f file` switch (which seems to be missing in the man page) but no such
  # luck for format or set-passphrase and `--no_passphrase` seems to forgo encryption altogether
  echo "Enter this passphrase: $(cat /etc/nixos/secret_local/bcachefs_key)"
  bcachefs format \
      --label=hdd.hdd1 /dev/hdd/hdd1e \
      --label=hdd.hdd2 /dev/hdd/hdd2e \
      --label=hdd.hdd3 /dev/hdd/hdd3e \
      --discard \
      --label=ssd.ssd1 /dev/ssd/ssd1e \
      --label=ssd.ssd2 /dev/ssd/ssd2e \
      --foreground_target=ssd \
      --promote_target=ssd \
      --background_target=hdd \
      --replicas=2 \
      --prjquota \
      --encrypted
  #bcachefs set-passphrase -f $key /dev/ssd/ssd1e
  bcachefs unlock -f $key /dev/ssd/ssd1e
fi

