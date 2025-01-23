#!/bin/sh
#NOTE We have to double-escape the Python program because of SSH.
tar -ch apply.py result-dns result-www result-mail \
  | ssh mailinabox python3 -BIc '"import sys,tarfile;tar=tarfile.open(fileobj=sys.stdin.buffer, mode=\"r|*\");exec(tar.extractfile(tar.next()).read())"' "$@"

