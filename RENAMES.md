# Changes that break callers

Renames, moves and removed names, newest first. A release that changes a name
or a module path adds an entry here.

## 0.2.0

`GRV_tree.Tree` no longer has `start` and `stop` (absolute offsets) or `error_at`: nodes
carry `padding` and `size`, and `Tree.has_errors()` says whether the parse had to recover.
`GRV_glr.parse` always returns a tree with a root. New modules: `GRV_edit`.

## 0.1.0

The lint renames spell out abbreviations in internal names (`symbol` for `sym` and so on); the public modules of 0.0.1 keep their names. `GRV_peg`, `GRV_lex`: unchanged.

## 0.0.1

First version. Nothing to migrate.
