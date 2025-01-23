tar -c apply.py *.nix | python3 -BIc 'import sys,tarfile;tar=tarfile.open(fileobj=sys.stdin.buffer, mode="r|*");exec(tar.extractfile(tar.next()).read())' a b c

