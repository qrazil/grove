# grove

An incremental parser runtime for [m31](https://github.com/qrazil/m31), written in
m31, that reuses the tree-sitter grammar ecosystem **as data**.

**Status: design, with g1, g2, conflict resolution and the first external scanner (Lua) built (0.4.0).** The specification is in `docs/`. g1 turns
a grammar.json into LR tables and a lexer at load time and parses with them:
json and C fixtures are node-for-node identical to tree-sitter's trees. g2 adds an immutable tree, incremental reparse (a mid-file edit of a 1.7 MB JSON
file reparses in under 0.1 ms), time-sliced parsing and a first error recovery.
There is no query engine yet; Lua is the first language with an external scanner. Nothing is
released and nothing depends on grove yet.

## What it is for

The m3 editor needs a syntax tree for highlighting, structural text objects,
indentation, folds, language injections and incremental selection, with a
budget that never stalls the key path. Tree-sitter's C runtime is out: the
language rules out a C ABI for now. Its grammars are not: `tree-sitter
generate` first turns `grammar.js` into `grammar.json` (plus `node-types.json`),
and the editors' query files (`highlights.scm`, `injections.scm`,
`textobjects.scm`, `indents.scm`, `folds.scm`) are plain text. grove reads those
files directly:

```
grammar.json + node-types.json   ->   parse tables and lexer, built at load time (cached)
queries/*.scm                    ->   compiled queries, run on a byte range
text (the editor's lines)        ->   an incremental tree, parsed in time slices
```

The planned interface to the editor is `MED_ts` (`engine/MED_ts.m31` in m3):
parse, edit, highlights, objects, folds, indent, injections, selection.

## Non-goals

- No C ABI, no `prim "c"`, no C helper process. Not now, not as a fallback.
- Not a re-implementation of `tree-sitter generate`: it does not read
  `grammar.js` (a JavaScript DSL) and does not write `parser.c`.
- Not tree-sitter ABI-compatible: no `TSLanguage`, no language bindings, no
  WASM grammars, no loading of compiled `.so` parsers.
- No promise of identical trees on **erroneous** input (error recovery is the
  same family, not the same states; see `docs/SPEC.md` section 8). On valid
  input the goal is node-for-node equality with tree-sitter, checked by an
  oracle.
- Not a replacement for the lexical `syntax` library: that stays as the fallback
  for large files, languages without a grammar, and the first moments of a parse.
- No semantic analysis beyond what `locals.scm` queries express; no language
  server.
- External scanners (hand-written C in many grammars) are not loaded; the ones
  that matter are rewritten by hand in m31 (`docs/SPEC.md` section 6). Languages
  whose scanner is the language (yaml, markdown) may stay lexical.

## Documents

| file | what |
|---|---|
| `docs/SPEC.md` | the design: loading grammar.json, the parsing algorithm and why, incremental reparse, the tree, external scanners, queries, performance budget, error recovery, the test plan, milestones g0-g5 |
| `docs/GRAMMARS.md` | survey of the 23 first languages: size, scanner, difficulty, queries |
| `docs/QUESTIONS.md` | decisions for the owner, each with a recommendation |
| `docs/ORACLE.md` | how trees are compared against tree-sitter's |
| `docs/PERF.md` | measured numbers (tree-sitter baseline, grove prototype) |
| `experiments/` | the throwaway scripts behind the numbers in the docs, and their recorded output in `experiments/results/` |

## What exists

| module | what |
|---|---|
| `GRV_json` | an order-preserving JSON reader (the standard library's `json` loses object order, which grammar.json depends on) into flat integer arrays |
| `GRV_grammar` | grammar.json to a flat rule arena: all 16 rule types, `extras`, `externals`, `inline`, `supertypes`, `precedences`, `word` |
| `GRV_lang` | rules to symbols and productions: flattening, repeats, inline, fields, aliases, precedence |
| `GRV_lr` | LR(1) tables with safe state merging, precedence resolution, GLR forks |
| `GRV_regex`, `GRV_lexer` | lexical rules to a code-point NFA and lazily built DFAs per set of valid terminals |
| `GRV_glr`, `GRV_tree`, `GRV_edit` | the parser (graph-structured stack, resumable, incremental, recovering), the immutable tree and its dump, edits |
| `GRV_lex`, `GRV_peg` | the first prototype: position-set matching and a PEG interpreter; kept as a cross-check on json |

`tests/t_oracle.m31` compares grove's trees for 8 JSON and 6 C files with tree-sitter's
(dumped by nvim with the grammar's own compiled parser, `tests/oracle/`): byte
ranges and field names included, identical. `tests/oracle/compare.py` does the same for
any set of real files. `tests/data/` holds the json, c and lua `grammar.json` of
tree-sitter (MIT, with their licences) and small grammars for the tests. Measured
numbers: `docs/SPEC.md` section 14 and `docs/PERF.md`.

## Build and test

```
M31_ROOT=/path/to/m31-release LANGC=/path/to/m31c bash tests/test.sh
```

Uses the public m31 release v0.14.2. Checks `m31c -fmt --check`, `m31c -lint`,
and every `tests/t_*.m31`. `tests/tables.m31` and `tests/bench.m31` (not run by `test.sh`)
print table build and parse times: `tables GRAMMAR.json ...`, `bench GRAMMAR.json [TEXT]`. Regenerating the oracle dumps needs nvim
and a parser built from the same revision as the grammar:
`GROVE_PARSER_DIR=/dir/with/json.so bash tests/oracle/refresh.sh`.

## Layout

Follows the m31 project layout (`docs/project-layout.md` in the m31 repository):

```
deps                 project file (name grove, version 0.4.0)
core/GRV_*.m31       the library
tests/test.sh        the single way to run every check
tests/t_*.m31        unit tests (print "N passed, M failed" last)
tests/oracle/        tree-sitter dumps and the nvim script that makes them
tests/data/          vendored grammars (json)
experiments/         one-off scripts for the numbers in the docs
docs/                SPEC, GRAMMARS, QUESTIONS, ORACLE, PERF
.github/workflows/   test.yml, release.yml (pinned to m31 v0.14.2)
CHANGELOG.md, RENAMES.md
```
