# Read TAR from stdin, run first file as a Python script, make further entries available for the script.
# Non-seeking read of TAR files is officially supported with "r|..." modes.
# see https://docs.python.org/3/library/tarfile.html#tarfile-objects
#NOTE It doesn't make much sense to use this script. A short form of this will be passed as an argument.
import sys, tarfile

tar = tarfile.open(fileobj=sys.stdin.buffer, mode="r|*")
script_info = tar.next()
script = tar.extractfile(script_info)
exec(script.read())

