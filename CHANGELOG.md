# Changelog

## 0.2.0 (g2: incremental, resumable, recovering)

- `GRV_tree`: relative padding and size, lookahead window, immutable nodes that
  versions share, flags (extra, changed, fragile, error), balanced repeat nodes,
  `full()` for exact comparison, `compact()`.
- `GRV_edit`: `apply(tree, start, old_end, new_end)` copies the path to an edit and marks it.
- `GRV_glr`: `Parser` with `has_finished_after(budget_ns)` (resumable), reuse of unchanged
  subtrees by tree-sitter's conditions (reduce first when the first token asks for it),
  error recovery (ERROR nodes, skipped tokens, whole-input ERROR at the end), `begin`,
  `parse`, `reparse`. A parse now always has a root; `Tree.has_errors()` replaces the
  failure position.
- `GRV_lexer` reports how far it looked (`token_examined`); `GRV_lang` has an ERROR symbol.
- Tests: `t_incr` (incremental equals scratch on random edits, reuse ratio), `t_recover`
  (slicing, recovery, fuzz); `tests/oracle/report.sh` compares any number of real files
  (990 of 990 clean JSON files identical).
- Measured: reparse after one edit in a 1.7 MB JSON file 72 to 90 us (tree-sitter in nvim
  15 ms); parse 1.6 to 1.9 MB/s.
- Renamed: `Parser.step` is `has_finished_after`; `Tree.start/stop` are gone (relative
  positions), `Tree.node_symbol`, `padding`, `size` replace them.

## 0.1.0 (g1: tables and parser)

- `GRV_lang`: grammar.json rules to symbols and productions (cross product of
  SEQ/CHOICE, repeats to auxiliary rules, `inline`, fields, aliases, static and
  dynamic precedence, associativity, named precedences, externals as terminals,
  extras including non-terminal ones).
- `GRV_lr`: LR(1) tables merged where safe, precedence and associativity
  resolution, GLR forks where a conflict stays; entries sorted per state for a
  binary-search lookup.
- `GRV_regex`, `GRV_lexer`: lexical rules to a code-point NFA and a lazily built
  DFA per set of valid terminals; the longest-match, precedence and
  whitespace-extra rules inferred from the oracle (documented in the header).
- `GRV_glr`, `GRV_tree`: the parser (graph-structured stack, extras, fields,
  aliases, hidden nodes, supertypes, dynamic precedence) and the tree with the
  oracle's dump.
- `GRV_grammar` also reads `inline`, `supertypes`, `precedences` and `word`.
- Oracle: json (8 files) and c (6 files) identical to tree-sitter; `tests/oracle/
  dump_tree.m31` and `compare.py` compare any set of real files; 9 of the 21
  clean C files of a 90-file sample are identical (the rest are listed in
  `experiments/results/c_real_files.txt`).
- Tests: `t_lr`, `t_glr` (mini grammars in `tests/data/mini`), `t_oracle`
  now runs the LR/GLR parser; `tests/tables.m31` and `tests/bench.m31` print
  build and parse times; vendored c and lua grammars (MIT) next to json.
- Measured (docs/SPEC.md 14): tables build in 463 ms for c and 3.8 s for sql, parse
  runs at 1.6 MB/s.
- Lint renames: every abbreviation spelled out (`symbol`, `position`, ...).

## 0.0.1 (design)

First version: the specification and feasibility study, and a prototype.

- `docs/SPEC.md`, `docs/GRAMMARS.md`, `docs/QUESTIONS.md`, `docs/ORACLE.md`,
  `docs/PERF.md`.
- `core/GRV_json`, `GRV_grammar`, `GRV_lex`, `GRV_peg`: an order-preserving
  JSON reader, a grammar.json loader, a token matcher and a PEG interpreter
  (not the design; see the SPEC).
- Oracle: tree dumps by nvim (`tests/oracle/dump_sexp.lua`, `refresh.sh`) and
  8 JSON fixtures that grove reproduces exactly.
- `experiments/`: the scripts behind the numbers in the docs.
- Project skeleton from `m31c -init --lib` (m31 v0.14.2): `deps`, `tests/test.sh`,
  workflows.
