#!/bin/sh -e
export PATH=$coreutils/bin:$patch/bin
cp -r $src $out
chmod -R u+w $out
# patch was generated like this:
# diff -Naur --no-dereference default-config/ config/ >config.patch
patch -p1 -d $out <$configPatch
rm $out/mods-config/files/authorize
ln -s $secretsDir/users $out/mods-config/files/authorize
mv $out/certs $out/certs.example
ln -s $secretsDir/certs $out/certs
ln -s $secretsDir/client-secret.conf $out/
ln -s ../mods-available/sql $out/mods-enabled/
