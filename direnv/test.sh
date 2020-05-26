#!/bin/sh
save_path() {
  real="`realpath "$1"`"
  if [ "${1:0:11}" != "/nix/store/" ] && [ "${real:0:11}" == "/nix/store/" ]; then
    echo blub
    # symlink to Nix store --> find symlink that is not in Nix store
    x="$1"
    while true; do
      parent="`dirname "$x"`"
      realparent="`realpath "$parent"`"
      if [ "$x" == "$parent" ] ; then
        break
      elif [ "${realparent:0:11}" != "/nix/store/" ] ; then
        echo "blub4: $1 -> $x"
        echo "$x" >>.tmp_paths
        break
      fi
      x="$parent"
    done
  elif [ "${1:0:11}" != "/nix/store/" ] || [ "$1" != "$real" ] ; then
    # path is outside of Nix store or a symlink
    #FIXME Is there an easy method to detect whether a chain of symlinks has any part outside of the store?
    echo "$1" >>.tmp_paths
  fi
}
handle_output() {
  while read line; do
    if [ "${line:0:26}" == "trace: direnv watch_file: " ]; then
      save_path "${line:26}"
    else
      echo "$line"
    fi
  done
}
rm .tmp_paths
nix-build blub2.nix 2>&1|handle_output >&2
cat .tmp_paths
