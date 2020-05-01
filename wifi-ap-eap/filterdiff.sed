s_^([-]{3}) (default-config|orig|/nix/store/[^/]*)/(etc/raddb/)?_\1 a/_
s_^([+]{3}) (config|/nix/store/[^/]*)/_\1 b/_
/^[+-]{3} / s_\t[0-9]{4}-.*__
s/(diff -Naur --no-dereference ).*/\1.../
