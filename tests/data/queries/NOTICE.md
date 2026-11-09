# Query files used by the tests

`json.scm`, `lua.scm` and `c.scm` are the `highlights.scm` files of nvim-treesitter
(<https://github.com/nvim-treesitter/nvim-treesitter>, commit
`cf12346a3414fa1b06af75c79faebe7f76df080a`, queries/json, queries/lua, queries/c), which is
distributed under the Apache License 2.0 (`LICENSE-nvim-treesitter`).

Changes: `c.scm` has what the C grammar of the revision the tests use (tests/data/c/grammar.json) does not
have taken out, because tree-sitter refuses a query that names a node type the grammar lacks: the
anonymous nodes `"asm"`, `"__asm__"` and `"offsetof"`, and the patterns for `alignof_expression` and
`preproc_elifdef`. The other two files are unchanged.

## textobjects, folds, indents, injections (0.8.0)

`textobjects/c.scm` and `textobjects/lua.scm` are `queries/c/textobjects.scm` and `queries/lua/textobjects.scm`
of nvim-treesitter-textobjects (<https://github.com/nvim-treesitter/nvim-treesitter-textobjects>, branch
`master` at commit `5ca4aaa6efdcc59be46b95a3e876300cfead05ef`, Apache License 2.0, the same text as
`LICENSE-nvim-treesitter`). json has no textobjects file there.

`folds/`, `indents/` and `injections/` are the files of the same names from nvim-treesitter at commit
`cf12346a3414fa1b06af75c79faebe7f76df080a` (json has no injections file).

Changes, for the same reason as `c.scm` above (a query naming a node type the grammar revision lacks is
refused): in the C files whole patterns were taken out or one entry removed:

- `textobjects/c.scm`: the pattern naming `else_clause`;
- `folds/c.scm`: the `(gnu_asm_expression)` entry;
- `indents/c.scm`: two patterns naming `else_clause`;
- `injections/c.scm`: four patterns naming `string_content`.

The Lua and json files are unchanged.
