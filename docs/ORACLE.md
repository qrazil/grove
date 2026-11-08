# The oracle

Tree-sitter is the reference. nvim 0.11 with compiled parsers is on the
development machine, so tree-sitter's trees are a free, independent oracle for
grove's trees (the same idea as `syntax`'s `docs/ORACLE.md`, one level up: trees
instead of highlight captures).

## Pieces

- `tests/oracle/dump_sexp.lua` (`nvim -u NONE --headless -l`): for each
  `LANG<TAB>PATH` of a manifest, parse PATH with the parser for LANG and write
  `OUT/PATH.sexp`: the named nodes, one per line, two spaces of indent per
  level, field names (`key: (string ...)`), byte ranges after a tab, `(ERROR`
  and `(MISSING x)` kept. Closing parentheses are on the node's last line.
- `tests/oracle/refresh.sh`: runs it for `tests/oracle/fixtures.tsv`, writes
  `tests/oracle/ts/`. Committed, so CI does not need nvim.
- `tests/t_oracle.m31`: parses each fixture with grove's grammar and compares
  the dump to the committed one, exactly (types, fields, byte ranges).

## The rule that matters: same revision

A `grammar.json` describes one revision of a grammar. If the parser that
produces the oracle was built from another revision, trees differ for reasons
that are not grove's. Observed: tree-sitter-json's grammar.json on this machine
nests `escape_sequence` inside `string_content`; nvim-treesitter's compiled json
parser (revision 46aa487b) does not. `GROVE_PARSER_DIR` points the dump script
at a directory of `LANG.so` built from the same checkout as the grammar.json
under test; without it nvim-treesitter's parsers are used, which is right only
if grammar.json comes from nvim-treesitter's pinned revision too. The
manifest `grammars.lock` (planned, SPEC 2.1) will record the tuple.

## Planned (SPEC 11)

Anonymous nodes in the dump; leaf-token stream comparison to separate lexer from
parser bugs; capture comparison for queries; incremental-equals-scratch property
tests (no oracle needed); fuzzing; floors in `tests/oracle/floors.json` that only
go up.
