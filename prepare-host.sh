#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git-crypt gnupg pinentry.curses gawk gnused git coreutils psmisc monkeysphere

user="${USER:-root}"
#hostname=macnix
hostname="$(hostname)"
gpg_uid="$hostname, $user <$user@$hostname.local>"
admin_gpg_key=A7CF599DB8F0E0053F69FDF0D76426D14FDEEE3D
nixos_dir="/etc/nixos"
#nixos_dir=/tmp/nixos  # for debugging
# Highest level of secrets - only exist on the local machine, e.g. private keys.
# If such secrets have another place in /etc, there is no reason to copy it here, e.g. SSH host keys.
# This doesn't have to be a separate repo (i.e. can be just a subdir) because we also have a repo in /etc/nixos.
secrets_local_subdir=secret_local
secrets_local_dir="$nixos_dir/$secrets_local_subdir"
keydir="$secrets_local_dir/hostkeys"
# Secrets that are shared between some machines, e.g. WiFi credentials. They are encrypted
# by a group key when pushed to the remote git.
secrets_shared_repo="$nixos_dir/secret"
# Information that shouldn't be published together with my nixcfg repo but it will be
# in the Nix store on some hosts. Some of it may be encrypted because not all hosts need to
# see it.
# This directory will contain a filtered worktree of the shared-secrets repo.
private_repo="$nixos_dir/hosts/$hostname/private"
private_symlink="$nixos_dir/private"

set -eo pipefail

get_fprint() {
  gpg_uid="$1"

  # It would be so useful if gpg2 was giving us the key id but no.
  #
  # One might think that gpgme would be useful here but we don't
  # want to write C and gpgme-json has a binary mode and an
  # interactive mode - both of which aren't useful for a bash script
  fprint="$(gpg2 --textmode --batch --list-secret-keys "=$gpg_uid" | sed -n '/^sec / { n; s/^ \+//; p }')"

  # gpg2 may return more keys than we expect, e.g. "ca <...>" when
  # we ask for "a <...>". Let's detect this and fail.
  # -> This might be fixed by starting the uid with "=" but let's check anyway.
  if [ -n "$fprint" -a ${#fprint} -ne 40 ] ; then
    echo "Error: We expected exactly one key (for uid: $gpg_uid) but we got: $fprint" >&2
    exit 1
  fi

  echo "$fprint"
}

generate_key() {
  gpg_uid="$1"
  save_fprint_file="$2"

  ( set -x; gpg2 --batch --passphrase "" --quick-generate-key "$gpg_uid" rsa4096 default never )
  fprint="$(get_fprint "$gpg_uid")"
  if [ -z "$fprint" ] ; then
    echo "Error: We couldn't retrieve the fingerprint of the newly-generated key." >&2
    exit 1
  fi

  ( set -x; gpg2 --batch --passphrase "" --quick-add-key "0x$fprint" rsa4096 encrypt never )
  ( set -x; gpg2 --batch --passphrase "" --quick-add-key "0x$fprint" rsa4096 auth never )

  echo "fprint='$fprint'" >"$save_fprint_file"
}

get_auth_keygrip() {
  fprint="$1"
  #keygrip="$(gpg --textmode --batch --with-keygrip --list-keys "0x$fprint" | sed -n '/^sub .* \[A\]/,/./ { n; s/^ *Keygrip = //p }')"
  keygrip="$(gpg --with-colon --batch --with-keygrip --list-keys 0x$fprint \
    | awk -F: '{ if ($1 == "sub") { type=$12 }; if ($1 == "grp" && type == "a") {print $10} }')"
  if [ ${#keygrip} -ne 40 ] ; then
    echo "Error: We expected exactly one keygrip (for auth key of uid: $gpg_uid) but we got: $keygrip" >&2
    exit 1
  fi
  echo "$keygrip"
}

get_auth_fprint() {
  fprint="$1"
  fpr_of_auth_key="$(gpg --with-colon --batch --with-subkey-fingerprints --list-secret-keys 0x$fprint \
    | awk -F: '{ if ($1 == "ssb") { type=$12 }; if ($1 == "fpr" && type == "a") {print $10} }')"
  if [ ${#fpr_of_auth_key} != 40 ] ; then
    echo "Error: We expected exactly auth sub-key (for key 0x$fprint) but we got: $fpr_of_auth_key" >&2
    exit 1
  fi
  echo "$fpr_of_auth_key"
}

get_fprint_from_file() {
  gpg --with-colons --show-key | awk -F: '{ if ($1 == "fpr" && prev == "pub") { print $10 }; prev=$1 }'
}

delete_key_unsafe() {
  gpg_uid="$1"
  fprint="$(get_fprint "$gpg_uid")"
  if [ -z "$fprint" ] ; then
    echo "No existing key"
  else
    gpg2 --batch --yes --delete-secret-key "0x$fprint"
    gpg2 --batch --yes --delete-key "0x$fprint"
  fi
}

is_key_signed() {
  key_to_check="$1"
  signed_by="$2"
  gpg --batch --textmode --list-sigs --with-colons "0x$key_to_check" \
    | awk -v our="${signed_by:40-16:16}" -F: 'BEGIN { found=0 } { if ($1 == "sig" && $5 == our) { found=1 } } END { print found }'
}

trust_key() {
  key_to_trust="$1"
  our_key="$2"
  # state that this key is really for that id
  gpg --batch --default-key "0x$our_key" --quiet --quick-lsign-key "0x$key_to_trust"
  # trust signatures that are made by that key
  gpg --batch --import-ownertrust <<<"$key_to_trust:5:"
}

if [ "$UNSAFE_REMOVE_OLD_GPG_KEY" == "1" ] ; then
  delete_key_unsafe "$gpg_uid"  # for debugging
fi

### generate GPG key

if [ ! -d $keydir ] ; then
  ( umask 077; install -m 0700 -d $secrets_local_dir )  # explicit creation to specify permissions
  ( umask 077; install -m 0700 -d $keydir )
fi

if [ -e $keydir/info ] ; then
  . $keydir/info
  echo "Using existing key: $fprint"
else
  generate_key "$gpg_uid" "$keydir/info"
  . $keydir/info
fi
if [ ! -e $keydir/gpg.secret.asc ] ; then
  ( umask 077; gpg --armor --export-secret-key 0x$fprint >$keydir/gpg.secret.asc )
fi
auth_keygrip="$(get_auth_keygrip $fprint)"
if ! [ -e ~/.gnupg/sshcontrol ] || ! grep -qF "$auth_keygrip" ~/.gnupg/sshcontrol ; then
  echo "$auth_keygrip" >>~/.gnupg/sshcontrol
fi

### extract auth key from GPG and convert to SSH key

ssh_pubkeys_new=0
fpr_of_auth_key="$(get_auth_fprint $fprint)"
if [ ! -e $keydir/id_rsa -o $keydir/info -nt $keydir/id_rsa ] ; then
  # We want the auth subkey but monkeysphere would choose some other subkey, be default.
  # -> Get the correct fingerprint from GnuPG and pass it to monkeysphere.
  # see https://frizky.web.id/?p=103
  ( umask 077; gpg --export-options export-minimal,no-export-attributes --export-secret-keys --no-armor 0x$fprint | openpgp2ssh $fpr_of_auth_key >$keydir/id_rsa.tmp )
  mv $keydir/id_rsa.tmp $keydir/id_rsa
fi
if [ ! -e $keydir/id_rsa.pub -o $keydir/id_rsa -nt $keydir/id_rsa.pub ] ; then
  ( ssh-keygen -y -f $keydir/id_rsa | tr -d '\n'; echo " $user@$hostname,openpgp:0x${fpr_of_auth_key:32:8}" ) >$keydir/id_rsa.pub
  ssh_pubkeys_new=1
fi

# sanity check: Do we get the same pubkey from GPG and monkeysphere+OpenSSH?
a="$(gpg --export-ssh-key 0x$fprint)"
b="$(cat $keydir/id_rsa.pub)"
a2="$(awk '{print $1, $2}' <<<"$a")"
b2="$(awk '{print $1, $2}' <<<"$b")"
if [ "$a2" != "$b2" ] ; then
  echo "Error: SSH pubkeys are different!" >&2
  echo "  GPG: $a" >&2
  echo "    -> $a2" >&2
  echo "  SSH: $b" >&2
  echo "    -> $b2" >&2
  exit 1
fi

### add sync.wahrhe.it to known_hosts

if [ ! -e ~/.ssh/known_hosts ] ; then
  mkdir -p ~/.ssh
  touch ~/.ssh/known_hosts
fi
for host_alias in '[sync.wahrhe.it]:8022' '[163.172.39.101]:8022' ; do
  if ! ssh-keygen -F "$host_alias" >/dev/null ; then
    echo "$host_alias ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGWlaVpTl5VjOKdhtaxvxusvrWg91mhEPNPgw87JtYbp root@git" >.tmp
    echo "$host_alias ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDJNyKPADYiUcdLK/KF4FBLvGMvT1fZIOMVox3YzNoIQHPVOm+/wLLYYRDg0CfTPPoi4gyEH+k+7uRpqqOl9TmEVv4HTS6xXgrrdLo5L1m20dgjvM9Bt+5lJ1T/wQsZVrjcKNzZZcEPYJFgAQakw0unKOcHG9QVYH+P2bF18fgCxldTuIuE5Er/z3EYVEHbeF1QMisvnK8N7xTqVAiRfbpnUbiXoQ0VXod4yj7ol2Msv0mJF+vs8UGgLniMA2UAAhzrE618XoHcNOOUr66oLysP9EzSvLTVfGSf+9XD0X3Bn4/qiZC0RqVEKFOKFWVmort8wbmVb1gsec+CbGBd5L3QA/XwANcKq9wwFPyV3FSFzmiZ3eQIR/aUVXcxCbxnoVx28iyNnwqAGhhdsojsX8/K9ZknTa47XNvUBvOpCzkGSVI7j2HDVm5vAEJcKUTXCufAq/QWswutHPQLRGxNuD8PjdK/sMd/3+A4QXBt7Oucs/0f9X1U7TrVTCBDmr7FNbER9FVBv5P7U8W2mOn5wLj3792YGwMbxLknaWSSt0BLRpl08eEFZoaz65XPHesiPS2oYQRGQ/2CRNjtqFQQeKdWqdO6kDVD2DaYbg0+7zd2IC10uingqNSrwl6ZmzfYJUNwC64Lqn63q552OeUPTXrKnmCVqZrdGi9UBQ9Q5mjnHw== root@git" >>.tmp
    ssh-keygen -H -f .tmp &>/dev/null
    cat .tmp >>~/.ssh/known_hosts
    rm .tmp.old .tmp
  fi
done

### test SSH keys

if [ ! -e $keydir/ssh_config ] ; then
  sed 's/^    //' <<EOF >$keydir/ssh_config
    Host sync sync-gpg sync-ssh
      # git container in nixosvm
      HostName sync.wahrhe.it
      Port 8022
      User git
      IdentitiesOnly yes
      PubkeyAuthentication yes
    Host sync sync-ssh
      IdentityFile $keydir/id_rsa
    Host sync-ssh
      IdentityAgent none
    Host sync sync-gpg
      # This answer suggests that one could use a public key with IdentitFile.
      # https://serverfault.com/a/964317
      # -> SSH was complaining but now it works.
      IdentityFile $keydir/id_rsa.pub
EOF
fi

if [ $ssh_pubkeys_new == 0 -a ! \( -e "$secrets_shared_repo/.git" -a -e "$private_repo/.git" \) ] ; then
  if ( set -x; ssh -F $keydir/ssh_config -o BatchMode=yes sync-ssh info </dev/null ) ; then
    echo "-> SSH key can be used to access host sync."
  else
    echo "-> SSH key doesn't work (yet)."
    ssh_pubkeys_new=1
  fi

  # We cannot set a non-default path for the sockets. The option
  # --no-use-standard-socket has no effect anymore. The list of
  # base directories is hardcoded so we really have no chance:
  # https://github.com/gpg/gnupg/blob/260bbb4ab27eab0a8d4fb68592b0d1c20d80179c/common/homedir.c#L622
  # -> The temporary agent will replace a running agent, which will
  #    hopefully notice that and restart. Our agent should automatically
  #    terminate itself "after a few seconds" when the child process
  #    is done.
  # Unfortunately, this check often fails without producing any output. I have no idea why.
  # -> No need to test this because id_rsa is the same key - thanks to monkeysphere.
  if false ; then
    killall -u $USER gpg-agent || true
    sleep 1
    if ( set -x; gpg-agent --verbose --batch --enable-ssh-support --steal-socket --daemon  bash -c "sleep 1; ssh -F $keydir/ssh_config -o BatchMode=yes sync-gpg info" ) </dev/null ; then
      echo "-> GnuPG key can be used to access host sync."
    else
      echo "-> GnuPG key doesn't work (yet). Exit code: $?"
      ssh_pubkeys_new=1
    fi
  fi
fi

if [ $ssh_pubkeys_new != 0 ] ; then
  (
    echo ""
    echo "=================================="
    echo ""
    echo "Please add this pubkey to the gitolite config as user $hostname (keydir/$hostname.pub) and add that user to the @hosts group."
    echo ""
    echo "cat $keydir/id_rsa.pub"
    echo ""
    cat $keydir/id_rsa.pub
  ) >&2
  exit 1
fi

# We assume that a useful config for connecting to the sync host will be included
# in the system config but we don't want to rely on it, yet.
set -x
export GIT_SSH_COMMAND="ssh -F $keydir/ssh_config -o BatchMode=yes"
set +x

### move existing /etc/nixos

if [ -e $nixos_dir -a \( ! -L $nixos_dir/nixos-rebuild.sh -o -L $nixos_dir/secret \) ] ; then
  # remove if empty
  if [ -e $nixos_dir.prepare-host.old ] ; then
    rmdir $nixos_dir.prepare-host.old || true
  fi

  if [ -e $nixos_dir.prepare-host.old ] ; then
    echo "Error: The backup dir already exists and isn't empty: $nixos_dir.prepare-host.old" >&2
    exit 1
  fi

  echo "Moving $nixos_dir to $nixos_dir.prepare-host.old"
  mv $nixos_dir $nixos_dir.prepare-host.old
  mkdir $nixos_dir
  mv $nixos_dir.prepare-host.old/$secrets_local_subdir $nixos_dir
fi

### create new /etc/nixos

mkdir -p $nixos_dir
cd $nixos_dir

if [ ! -e $nixos_dir/.git ] ; then
  ( umask 077; git -c init.defaultBranch=main init . )
  for x in flake.nix nixos-rebuild.sh ; do
    ln -s flake/$x ./$x
    git add $x
  done
fi

if [ ! -e $secrets_local_dir ] ; then
  if [ -e $nixos_dir.prepare-host.old/secrets_local_subdir/.git ] ; then
    mv "$(realpath $nixos_dir.prepare-host.old/$secrets_local_subdir)" $secrets_local_dir
    git add $secrets_local_dir
  elif [ -e $secrets_local_dir/.git ] ; then
    # already moved in the code above
    git add $secrets_local_dir
  else
    # no legacy repo -> make it a normal directory
    install -m 0700 -d $secrets_local_dir
    # add some random data so the git commit hashes won't reveal anything
    # (in case a commit hash is ever leaked by something)
    dd if=/dev/urandom of=$secrets_local_dir/random bs=1 count=1024
    git add $secrets_local_dir/random
  fi
fi
if [ -e $nixos_dir.prepare-host.old/hostkeys -a ! -e $secrets_local_dir/hostkeys ] ; then
  mv $nixos_dir.prepare-host.old/hostkeys $secrets_local_dir/hostkeys
  if [ ! -e $secrets_local_dir/.git ] ; then
    git add $secrets_local_dir/hostkeys
  fi
fi

if [ ! -e $secrets_shared_repo ] ; then
  ( umask 077; set -x; git submodule add -b main sync:nixcfg-secret ${secrets_shared_repo#$nixos_dir/} ) </dev/null
fi

sparse_list=$secrets_shared_repo/sparse-configs-for-private/"$hostname"
sparse_template=$secrets_shared_repo/sparse-configs-for-private/TEMPLATE
if [ ! -e "$sparse_list" ] ; then
  mkdir -p $secrets_shared_repo/sparse-configs-for-private
  sed 's/^    //' <"$sparse_template" >"$sparse_list"
  if [ -e "$sparse_template" ] ; then
    sed "s/{HOST}/$hostname/" <$sparse_template >"$sparse_list"
  fi
  ( set -x; cd $secrets_shared_repo && git add sparse-configs-for-private/"$hostname" \
    && git commit -m "init sparse-checkout config for private dir on $hostname" -S0x$fprint )
fi

if [ ! -e $private_repo ] ; then
  # private repo is a worktree of the secret repo
  ( umask 077; set -x; cd ${secrets_shared_repo#$nixos_dir/} && git worktree add -b private --no-checkout $private_repo )

  # add it as a fake submodule so git doesn't complain
  ( set -x; git submodule add -b no-such-branch--worktree-of-secret sync:nixcfg-secret ${private_repo#$nixos_dir/} )
fi
gitdir="$(cd $private_repo && git rev-parse --git-dir)"
if [ "$(cd $private_repo && git config --worktree core.sparseCheckout 2>/dev/null)" != "true" ] ; then
  # configure sparse checkout
  ( cd $private_repo && git sparse-checkout init && git config --worktree core.sparseCheckoutCone false )
  if [ ! -e "$gitdir/info/sparse-checkout" ] ; then
    echo "Error: Sparse-checkout file must already exist. We think that it should be here: $gitdir/info/sparse-checkout" >&2
    exit 1
  fi
  #NOTE `git sparse-checkout add` keeps this symlink.
  ( set -x; ln -sfT "$sparse_list" "$gitdir/info/sparse-checkout" )

  # reset index because `--no-checkout` has marked all files as deleted
  ( cd $private_repo && git reset --quiet )
fi
if [ ! -L "$gitdir/info/sparse-checkout" -o ! -e "$gitdir/info/sparse-checkout" ] ; then
  echo "Error: sparse-checkout file should be a symlink!" >&2
  echo "Run this command to fix that: ln -sfT \"$sparse_list\" \"$gitdir/info/sparse-checkout\"" >&2
  exit 1
fi
if [ ! -e $private_symlink ] ; then
  ln -s "${private_repo#$nixos_dir/}" $private_symlink
  git add $private_symlink
fi

if [ ! -e flake/.git ] ; then
  ( set -x; git submodule add https://github.com/BBBSnowball/nixcfg flake )
  ( set -x; cd flake && git remote add stage sync:nixcfg )
fi

### enable signed commits for our gits

# $secrets_local_dir is probably not a git but then it will just be set on the parent repo, again.
# (Setting gpg.format is optional because it is the default - unless we have changed it in the global git config.)
for x in $nixos_dir $nixos_dir/flake $secrets_local_dir $secrets_shared_repo $private_repo ; do
  ( set -x; cd $x && git config commit.gpgsign true && git config gpg.format openpgp && git config user.signingkey 0x$fprint )
done

# Make a "TODO" smudge filter. We use that to mark paths in the secret repo that might need encryption.
# The filter will any accidental staging of such files.
for x in $secrets_shared_repo $private_repo ; do
  ( cd $x && git config filter.TODO.smudge false )
  ( cd $x && git config filter.TODO.clean false )
  ( cd $x && git config filter.TODO.required true )
done

### create first commit

if [ ! -e .git/refs/heads/main -a ! -e .git/refs/heads/master ] ; then
  ( set -x; git add ${keydir#$nixos_dir/} )
  ( set -x; git commit -m "initial commit (by prepare-host.sh)" -S0x$fprint )
fi

### commit&push GPG public key

if [ ! -e $secrets_shared_repo/keys/"$user@$hostname.gpg.pub" ] ; then
  mkdir -p $secrets_shared_repo/keys
  cp $keydir/id_rsa.pub $secrets_shared_repo/keys/"$user@$hostname.ssh.pub"
  for x in /etc/ssh/ssh_host_*.pub ; do
    ssh-keygen -l -f "$x" | sed 's/^/# /'
    cat "$x"
  done >$secrets_shared_repo/keys/"$hostname.ssh_host.pub"
  gpg --armor --export 0x$fprint >$secrets_shared_repo/keys/"$user@$hostname.gpg.pub.tmp"
  # Only now create the .gpg.pub file, which means we won't enter this "if" branch again.
  mv $secrets_shared_repo/keys/"$user@$hostname.gpg.pub.tmp" $secrets_shared_repo/keys/"$user@$hostname.gpg.pub"

  # If this fails for whatever reason, the user must clean it up. Sorry.
  ( set -x;
    cd $secrets_shared_repo && git add keys/{"$hostname.ssh_host.pub","$user@$hostname.ssh.pub","$user@$hostname.gpg.pub"} \
    && git commit -m "add public keys for host $hostname" -S0x$fprint \
    && git push -u origin main:"$hostname/main" )
fi

### check signature and git-crypt access for GPG key

# We can extract the fingerprint from admin.gpg.pub because we have to
# trust this repo anyway and the admin will notice if we have pushed to the
# wrong tree in the previous step.
# Nonetheless, let's not do this, for now. We will mark the key as trusted
# and the admin may forget to undo that if they detect a MITM situation.
#admin_gpg_key="$(get_fprint_from_file <$secrets_shared_repo/keys/admin.gpg.pub)"

if ! gpg2 --textmode --batch --list-keys 0x$admin_gpg_key &>/dev/null ; then
  gpg --import "$secrets_shared_repo/keys/admin.gpg.pub"
fi

trust_key "$admin_gpg_key" "$fprint"

if [ "$(is_key_signed $fprint $admin_gpg_key)" != "1" ] ; then
  echo "Our key is not yet signed by $admin_gpg_key  -> try to fetch repo and import key again (might have been updated)"
  ( cd $secrets_shared_repo && git pull origin main ) \
  && gpg --import "$secrets_shared_repo/keys/$user@$hostname.gpg.pub" \
  || echo "We couldn't fetch but we will continue to print the next messages."
fi

needs_action=0
if [ "$(is_key_signed $fprint $admin_gpg_key)" != "1" ] ; then
  echo "Our key is not yet signed by $admin_gpg_key."
  needs_action=1
fi
if [ ! -e $secrets_shared_repo/.git-crypt/keys/all/0/$fprint.gpg ] ; then
  echo "Our key doesn't have access to git-crypt, yet."
  needs_action=1
fi

if [ $needs_action != 0 ] ; then
  (
    echo ""
    echo "=================================="
    echo ""
    echo "Please sign our GPG key and add it to git-crypt:"
    echo ""
    echo "  cd nixcfg-secret"
    echo "  git pull origin $hostname/main"
    echo "  gpg --import keys/$user@$hostname.gpg.pub && gpg --default-key 0x$admin_gpg_key --quick-sign-key 0x$fprint && gpg --armor --export 0x$fprint >keys/$user@$hostname.gpg.pub"
    echo "  git-crypt add-gpg-user -n -k all 0x$fprint   # can be repeated for other groups"
    echo "  git add keys/$user@$hostname.gpg.pub && git commit -m \"sign key for host $hostname\" && git push origin main"
    exit 1
  ) >&2
fi

### unlock repos

for repo in $secrets_shared_repo ; do
  if [ "$(tr -d '\0' <"$repo/.decryption_test")" != "decrypted" ] ; then
    ( set -x; cd $repo && git-crypt unlock )
  fi
done

# private repo is a worktree of secret, which git-crypt doesn't seem to support so well
# -> just use the same decrypted keys for both
gitdir1="$(cd $secrets_shared_repo && git rev-parse --git-dir)"
gitdir2="$(cd $private_repo && git rev-parse --git-dir)"
mkdir -p $gitdir2/git-crypt
( set -x; ln -sfT "$gitdir1/git-crypt/keys" "$gitdir2/git-crypt/keys" )
# Now, we can undo the "deletion" of those files that we haven't checked out, yet.
if [ ! -e $private_repo/.decryption_test ] ; then
  ( set -x; cd $private_repo && git ls-files -dz | xargs -0 git checkout )
fi

### done

(
  echo ""
  echo "=================================="
  echo ""
  echo "Preparations are done. Create a config for this host in $nixos_dir/flake/hosts/$hostname/main.nix" >&2
  echo "The old config is in $nixos_dir.prepare-host.old" >&2
) >&2

#FIXME add scripts for fixing up file rights in the repos (e.g. some secrets may be readable by certain groups) -> make sure that rights are only changed on the correct hosts! -> or maybe we don't want this for the repo and we should copy files, which needs special rights, to another dir

