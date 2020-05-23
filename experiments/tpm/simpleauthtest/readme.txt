set -e

# https://medium.com/@pawitp/full-disk-encryption-on-arch-linux-backed-by-tpm-2-0-c0892cab9704

#tpm2_createpolicy -P -L sha1:0,2,4,7 -f policy.digest
 tpm2_createpolicy --policy-pcr -l sha1:0,2,4,7 -L policy.digest

#tpm2_createprimary -H e -g sha1 -G rsa -C primary.context
 tpm2_createprimary -C e -g sha256 -G rsa -c primary.context -P abc
 #NOTE: sha256 is required here to avoid "Esys_ContextLoad(0x90006) - mu:A buffer isn't large enough"

#tpm2_create -g sha256 -G keyedhash -u obj.pub -r obj.priv -c primary.context -L policy.digest -A "noda|adminwithpolicy|fixedparent|fixedtpm" -I secret.bin 
 tpm2_create -g sha256              -u obj.pub -r obj.priv -C primary.context -L policy.digest -a "noda|adminwithpolicy|fixedparent|fixedtpm" -i secret.bin 

#tpm2_load -c primary.context -u obj.pub -r obj.priv -C load.context
 tpm2_load -C primary.context -u obj.pub -r obj.priv -c load.context

#tpm2_evictcontrol -c load.context -A o -S 0x81000000
 tpm2_evictcontrol -c load.context -C o 0x81000000 -P abc

rm load.context obj.priv obj.pub policy.digest primary.context

#tpm2_listpersistent
 tpm2_getcap handles-persistent

# probably after reboot

#tpm2_unseal -H 0x81000000 -L sha1:0,2,4,7
 tpm2_unseal -c 0x81000000 -p pcr:sha1:0,2,4,7
