#!/usr/bin/python3

# https://unix.stackexchange.com/questions/509413/can-i-mark-files-as-recently-used-from-the-command-line/509417#509417

import gi, sys
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gio, GLib

if len(sys.argv) == 1 or sys.argv[1] == "--help":
    print("Usage: %s file..." % sys.argv[0])
    print("")
    print("This adds the files to Gtk's recently used list.")
    sys.exit(1)

rec_mgr = Gtk.RecentManager.get_default()

for arg in sys.argv[1:]:
    rec_mgr.add_item(Gio.File.new_for_path(arg).get_uri())

GLib.idle_add(Gtk.main_quit)
Gtk.main()

