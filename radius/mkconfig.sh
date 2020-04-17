#!/bin/sh -e
export PATH=$coreutils/bin:$patch/bin
cp -r $src $out
chmod -R u+w $out
# patch was generated like this:
# diff -Naur --no-dereference default-config/ config/ >config.patch
patch -p1 -d $out <$configPatch
rm $out/sites-enabled/default
rm $out/mods-config/files/authorize
ln -s /etc/nixos/radius/users $out/mods-config/files/authorize
