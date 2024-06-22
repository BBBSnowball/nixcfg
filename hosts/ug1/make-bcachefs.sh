bcachefs format \
    --label=hdd.hdd1 /dev/hdd/slow1 \
    --label=hdd.hdd2 /dev/hdd/slow2 \
    --label=hdd.hdd3 /dev/hdd/slow3 \
    --discard \
    --label=ssd.ssd1 /dev/ssd/fast1 \
    --label=ssd.ssd2 /dev/ssd/fast2 \
    --foreground_target=ssd \
    --promote_target=ssd \
    --background_target=hdd \
    --replicas=2 \
    --prjquota \

