let
  lib = import ./lib.nix {};

  assertEqual = a: b: if a == b then true else builtins.trace [ a b ] (assert (a == b); true);
  assertNull = a: if isNull a then true else builtins.trace a (assert (isNull a); true);
  assertNotNull = a: if ! isNull a then true else builtins.trace a (assert (! isNull a); true);
in
  assert assertNull (lib.compare 42 42);
  assert assertNotNull (lib.compare 42 23);

  assert assertNull (lib.compare [ 42 ] [ 42 ]);
  assert assertNotNull (lib.compare [ 42 ] [ 23 ]);
  assert assertNotNull (lib.compare [ 42 42 ] [ 42 ]);

  assert assertNull (lib.compare { a = 42; b = 23; } { a = 42; b = 23; });
  assert assertNotNull (lib.compare { a = 42; b = 23; } { a = 42; b = 42; });
  assert assertNotNull (lib.compare { a = 42; b = 23; } { a = 42; b = 23; c = 7; });
  assert assertNotNull (lib.compare { a = 42; b = 23; } { a = 42; c = 23; });
  assert assertNull (lib.compare { a.b.c = 42; d.e.f = 23; } { a.b.c = 42; d.e.f = 23; });
  assert assertNotNull (lib.compare { a.b.c = 42; d.e.f = 23; } { a.b.c = 42; d.e.f = 7; });

  assert assertNull (lib.compare (x: 0) (x: 1));
  assert assertNull (lib.compare { a = 42; b = (x: 0); } { a = 42; b = (x: 1); });
  assert assertNotNull (lib.compare { a = 42; b = (x: 0); } { a = 42; b = (x: 1); c = (x: 2); });

  "ok"
