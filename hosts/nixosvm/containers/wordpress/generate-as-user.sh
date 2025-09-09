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

#cd "$(dirname "$0")"
t="$(umask 077; mktemp -d)"
cp {plugins,themes,pluginLanguages,themeLanguages}.json "$t/" || true
chown -R generate-files "$t"
#ln -s "$PWD"/wordpress-{plugins,themes}.json "$t/"
#sudo -u generate-files -D "$t" WP_VERSION="$WP_VERSION" "$PWD/generate.sh"
cmd="$PWD/generate-inner.sh"
#( set -x; cd "$t" && sudo -u generate-files WP_VERSION="$WP_VERSION" PLUGINS="$PLUGINS" THEMES="$THEMES" PATH="$PATH" bash "$cmd" )
#( set -x; cd "$t" && sudo -u generate-files --preserve-env=WP_VERSION,PLUGINS,THEMES,PATH bash "$cmd" )
( set -x; cd "$t" && sudo -u generate-files --preserve-env=WP_VERSION,PATH "`which wp4nix`" -p $PLUGINS -pl en,de,de_DE -t $THEMES -tl en,de,de_DE )
rm -f {plugins,themes,pluginLanguages,themeLanguages}.json
cp -L "$t"/{plugins,themes,pluginLanguages,themeLanguages}.json .

