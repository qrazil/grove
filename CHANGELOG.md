# Changelog

## 0.5.0 (queries, subset Q0)

- `GRV_query`: parse and run tree-sitter queries over the visible tree: patterns, fields, negated
  fields, captures, alternations, sibling groups, quantifiers, anchors, wildcards, `(ERROR)`;
  predicates `#eq? #not-eq? #any-eq? #match? #lua-match? #any-of? #has-ancestor? #has-parent?` and
  `not-` forms; directives `#set!` and `#offset!`. `GRV_find`: the regex and Lua-pattern matcher behind
  them. SPEC section 18.
- Oracle: nvim-treesitter highlights for json, c, lua (vendored, `tests/data/queries`) against nvim's own
  captures: 45 committed fixtures identical; real files json 284/284, lua 299/299, c 93 identical and 3
  different (the same three tree differences as the tree oracle).
- Fix from the oracle: a rule that is only a string keeps the anonymous token as its child when the
  string is also written inline (Lua `empty_statement` and `;`); a TOKEN wrapping only a string is an
  anonymous token (C `preproc_params`).
- Tests: `t_find` (18), `t_query` (46), `t_query_oracle` (48). Tools: `tests/oracle/report_captures.sh`,
  `refresh_captures.sh`, `dump_captures.lua`, `dump_captures.m31`, `compare_captures.py`.

## 0.4.0 (external scanners, Lua)

- `GRV_scan`: the `Scanner` interface and `ScanLexer`; `GRV_scanners.for_language`;
  `GRV_scan_lua`: tree-sitter-lua's scanner in m31.
- The lexer calls the scanner first when a state accepts external tokens; scanner state is saved
  per stack entry and restored before each scan; tree flags `HAS_EXTERNAL` and `ENDS_OPEN` keep
  incremental reuse sound (a node is reused only when the scanner was and ends at rest).
- Lua: 7 fixtures and 399 of 400 real files identical to tree-sitter; incremental equals scratch for Lua
  with hostile edits; reparse after an edit 141 to 169 us on 295 KB.
- Fixes found on the way: a rule that is only a token and the same token inline are two terminals;
  a token matching the empty string is a zero-width token when nothing else matches; fragility
  propagates to a node from its first or last child; nodes reduced for a lookahead that is then
  rejected, or on a stack above an ERROR, are fragile.
- Tests: `t_scan` (22), Lua in `t_oracle` (7 fixtures), `t_incr`, `t_recover` (fuzz + unclosed bracket).

## 0.3.0 (conflict resolution)

- Found why the fork counts differed from "the declared conflicts": tree-sitter's own tables
  hold 162 fork pairs for C, 1 547 for Python, 1 721 for Kotlin, and keep the repeat tie as a
  fork; the comparison is by class (SPEC 16). `tests/forks.m31`, `experiments/ts_forks.py`,
  `ts_fork_classes.py`, `compare_forks.sh`.
- Fixed from that comparison: associativity with precedence 0 across `inline`; named
  precedences above integers; a shift takes the precedence of the kernel items that lead to it;
  which version survives follows `ts_parser__select_tree` (errors, dynamic precedence, then
  `ts_subtree_compare`: lower symbol id, fewer children).
- Tables: canonical LR(1) identity for the terminals on which any state conflicts, LALR for the
  rest, then merging of states with compatible rows; a state limit falls back to LALR for the
  big grammars (rust, typescript, cpp, kotlin, sql, bash). `a = b = c`, which 0.1.0 claimed to
  parse, now does. C: 24 forks in the same 7 classes as tree-sitter's.
- Lexer: after a character that began a token, a token of higher precedence than the one
  accepted may still start (`#define X /* c */`).
- Oracle: `dump_sexp.lua` prints anonymous MISSING nodes, so tree-sitter's own error recovery is
  no longer counted as a difference: C, 140 of 143 comparable files identical (was 136 of 202).
- Tests: `t_incr` now applies each random edit and undoes it, comparing after both (equal
  whenever the text is valid); a tie-break test and two C micro fixtures (`resolve.c`,
  `macro_comment.c`).

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
