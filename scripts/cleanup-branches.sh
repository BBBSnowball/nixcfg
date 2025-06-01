#!/usr/bin/env bash

# find remote branches like hostname/main2 and remove main and main2
git branch --all --list --format "%(refname)" | sed 's_^refs/remotes/origin/\([-a-zA-Z0-9_/]\+\)\([0-9]\)$_\1\n\1\2_p' -n | sort -u | while read x ; do ( set -x; git push origin :"$x" ) ; done

