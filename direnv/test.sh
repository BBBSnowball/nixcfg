nix-build blub2.nix 2>&1|sed -En "s/^trace: direnv watch_file: (.*)$/\1/p"|while read f ; do if [ "${f:0:11}" != "/nix/store/" ] || [ "$f" != "`realpath "$f"`" ] ; then echo "somewhere else: $f" ; fi ; done
