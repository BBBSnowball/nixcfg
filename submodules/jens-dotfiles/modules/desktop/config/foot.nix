{ lib, pkgs, config, ... }:
with lib;
pkgs.writeText "foot.ini" ''
# foot config file

dpi-aware=no

font=monospace:size=10.5

[scrollback]
lines=10000

[mouse]
hide-when-typing=yes

[colors]
foreground=ebdbb2
background=1d2021
regular0=282828  # black
regular1=cc241d  # red
regular2=98971a  # green
regular3=d79921  # yellow
regular4=458588  # blue
regular5=b16286  # magenta
regular6=689d6a  # cyan
regular7=a89984  # white
bright0=928374   # bright black
bright1=fb4934   # bright red
bright2=b8bb26   # bright green
bright3=fabd2f   # bright yellow
bright4=83a598   # bright blue
bright5=d3869b   # bright magenta
bright6=8ec07c   # bright cyan
bright7=ebdbb2   # bright white

[key-bindings]
spawn-terminal=Control+Shift+Return
''
