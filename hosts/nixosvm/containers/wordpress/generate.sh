#!/usr/bin/env nix-shell
#!nix-shell -i bash -p wp4nix jq
set -eo pipefail
if [ -z "$WP_VERSION" ] ; then
  echo "Usage: WP_VERSION=... $0" >&2
  echo "Or better run it via the flake: nix run .#update-wordpress" >&2
  exit 1
fi
if [ ! -e wordpress-plugins.json ] ; then
  echo "Run this in the directory that contains wordpress-plugins.json, e.g. hosts/nixosvm/containers/wordpress" >&2
  exit 1
fi

echo "Generating for Wordpress $WP_VERSION ..."
export PLUGINS="`< wordpress-plugins.json jq -r 'keys|join(",")'`"
export THEMES="`< wordpress-themes.json jq -r 'keys|join(",")'`"

t="$(umask 077; mktemp -d)"
# Does wp4nix use the existing values, e.g. don't download again when version hasn't changed?
# We don't know but it seems to read the existing files so let's make them available.
cp {plugins,themes,pluginLanguages,themeLanguages}.json "$t/" || true
chown -R generate-files "$t"
( set -x; cd "$t" && sudo -u generate-files --preserve-env=WP_VERSION,PATH "`which wp4nix`" -p $PLUGINS -pl en,de,de_DE -t $THEMES -tl en,de,de_DE )
rm -f {plugins,themes,pluginLanguages,themeLanguages}.json
cp -L "$t"/{plugins,themes,pluginLanguages,themeLanguages}.json .
sudo -u generate-files rm -rf "$t"

