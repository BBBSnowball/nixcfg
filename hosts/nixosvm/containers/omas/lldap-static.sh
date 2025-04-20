IFS=$'\n'
a=( $(htmlq "*[integrity]" <$src/index.html) )
b=( $(htmlq "*[integrity]" <$src/index_local.html) )
c=( $(cat $src/static/libraries.txt) )
d=( $(cat $src/static/fonts/fonts.txt) )
unset IFS

# find integrity hashes and URLs in index.html
declare -A src
for line in "${a[@]}" ; do
  i="$(htmlq -a integrity '*' <<<"$line")"
  s="$(htmlq -a src '*' <<<"$line")$(htmlq -a href '*' <<<"$line")"
  #echo "$i -> $s" >&2
  src["$i"]="$s"
done

# find integrity hashes and local paths in index_local.html
declare -A tgt
declare -A hash
for line in "${b[@]}" ; do
  i="$(htmlq -a integrity '*' <<<"$line")"
  s="$(htmlq -a src '*' <<<"$line")$(htmlq -a href '*' <<<"$line")"
  #echo "$i -> $s" >&2
  if [[ "$s" != /static/* ]] ; then
    echo "WARN: Path doesn't match! $i -> $s" >&2
  else
    s="${s#/static/}"
    tgt["$i"]="$s"
    hash["$s"]="$i"
  fi
done

# add more paths from text files
for line in "${c[@]}" ; do
  p="${line##*/}"
  # sha384 is not supported by Nix.
  if [[ -z "${hash[$p]}" || "${hash[$p]}" == sha384* ]] ; then
    echo "Prefetching hash for $p..." >&2
    h="$(nix-prefetch-url "$line")"
    hash["$p"]="$h"
    src["$h"]="$line"
  fi
done
for line in "${d[@]}" ; do
  p="fonts/${line##*/}"
  if [[ -z "${hash[$p]}" || "${hash[$p]}" == sha384* ]] ; then
    echo "Prefetching hash for $p..." >&2
    h="$(nix-prefetch-url "$line")"
    hash["$p"]="$h"
    src["$h"]="$line"
  fi
done

#declare -p src
#declare -p tgt
#declare -p hash

echo "{ fetchurl }:"
echo "{"
for path in "${!hash[@]}" ; do
  h="${hash[$path]}"
  s="${src[$h]}"
  echo "  \"$path\" = fetchurl {"
  echo "    url = \"$s\";"
  if [[ "$h" == *-* ]] ; then
    echo "    hash = \"$h\";"
  else
    echo "    sha256 = \"$h\";"
  fi
  echo "  };"
done
echo "}"

