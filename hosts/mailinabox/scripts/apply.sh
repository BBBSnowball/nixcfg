#!/bin/sh
#NOTE We have to double-escape the Python program because of SSH.
tar -ch apply.py -C result-all dns.yaml www.yaml mail.json \
  | ssh mailinabox python3 -BIc '"import sys,tarfile;tar=tarfile.open(fileobj=sys.stdin.buffer, mode=\"r|*\");exec(tar.extractfile(tar.next()).read())"' "$@"

