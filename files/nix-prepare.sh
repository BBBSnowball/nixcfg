set -eo pipefail
#set -x

#if [ -e /real-root/opt/nix/nix.mount -a -e /real-root/nix/nix.mount ] ; then
#  echo "/nix is already mounted"
#  exit 0
#fi

# see https://github.com/NixOS/nix/blob/88a45d6149c0e304f6eb2efcc2d7a4d0d569f8af/scripts/install-multi-user.sh
install -dv -m 0755 /real-root/opt/nix /real-root/opt/nix/var /real-root/opt/nix/var/log /real-root/opt/nix/var/log/nix /real-root/opt/nix/var/log/nix/drvs /real-root/opt/nix/var/nix{,/db,/gcroots,/profiles,/temproots,/userpool,/daemon-socket} /real-root/opt/nix/var/nix/{gcroots,profiles}/per-user
install -dv -g nixbld -m 1775 /real-root/opt/nix/store
install -dv -o 1000 -m 0755 /real-root/opt/nix/var/nix/{gcroots,profiles}/per-user/deck

if [ ! -e /real-root/root/.nix-channels ] ; then
  echo "https://nixos.org/channels/nixpkgs-unstable nixpkgs" > "/tmp/.nix-channels"
  install -m 0664 "/tmp/.nix-channels" "/real-root/root/.nix-channels"
fi

for src in /nix/store/* ; do
  dst="/real-root/opt$src"
  tmp="$dst.tmp$$"
  rm -rf "$tmp"
  if [ ! -e "$dst" ] ; then
    cp -RPp "$src" "$tmp"
    chmod -R a-w "$tmp"
    mv -T "$tmp" "$dst"
  fi
done

#FIXME We would like to make a profile that points to the rootfs of the portable service in our nix store but that would
#      be a circular dependency. Maybe we want a host config without the nix-prepare service and then use that..?
#chroot /real-root $(which nix-env) -p /nix/var/nix/profiles/nix-service --set ...
if [ ! -e /real-root/etc/nix ] ; then
  cp -dRLT /etc/nix /real-root/etc/nix
fi

# Add profile script to shell profile.
if [ ! -e /real-root/etc/profile.d/nix.sh ] ; then
  #FIXME This should also be a symlink.
  cat >/real-root/etc/profile.d/nix.sh <<"EOF"
  # added by nix-deck portable service
  export NIX_REMOTE=daemon
  if [ -r "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi
EOF
fi

# Trick 1: A mount in the service would only be visible to us but we can tell systemd to do the mount for us.
cat >/real-root/opt/nix/nix.mount <<"EOF"
[Unit]
Description=Nix Store
Before=nix-daemon.service nix-gc.service nix-optimise.service

[Mount]
Where=/nix
What=/opt/nix
Type=none
Options=bind

#[Install]
#WantedBy=local-fs.target
EOF
# I think this is ignored by systemd because the symlink is broken when it reads the files (because /opt isn't mounted at that time).
#ln -sfT /opt/nix/nix.mount /real-root/etc/systemd/system/nix.mount
cp /real-root/opt/nix/nix.mount /real-root/etc/systemd/system/nix.mount

# Trick 2: systemctl will refuse to work in chroot - unless that chroot is identical to the main root fs.
chroot /real-root /usr/bin/systemctl daemon-reload
chroot /real-root /usr/bin/systemctl start nix.mount

# This cannot work yet because /nix is not mounted in /real-root, yet - if we are on a fresh install. It isn't necessary anyway.
#if [ ! -e /real-root/opt/nix/var/nix/db/db.sqlite ] ; then
#  chroot /real-root $(which nix-store) --verify
#fi

set +x

