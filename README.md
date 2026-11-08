# grove

An incremental parser runtime for [m31](https://github.com/qrazil/m31), written in
m31, that reuses the tree-sitter grammar ecosystem **as data**.

**Status: design (0.0.1).** The specification and a feasibility study are in
`docs/`; the only code is a prototype that answers questions in them (below).
Nothing is released and nothing depends on grove yet.

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

## The prototype

Four modules in `core/`, 58 checks in `tests/`:

| module | what |
|---|---|
| `GRV_json` | an order-preserving JSON reader (the standard library's `json` loses object order, and grammar.json is order-sensitive) into flat integer arrays |
| `GRV_grammar` | grammar.json to a flat rule arena: all 16 rule types, `extras`, `externals`, symbol resolution |
| `GRV_lex` | token matching by position sets over the rule arena, with a regex subset for PATTERN |
| `GRV_peg` | the grammar's rules interpreted as a PEG, producing a tree and its dump. Not the design (it is slow and only right for simple grammars); it proves the loader and the tree shape against the real tree-sitter on json |

`tests/t_oracle.m31` compares grove's tree for 8 JSON files to tree-sitter's
(dumped by nvim with the grammar's own compiled parser, `tests/oracle/`),
byte range and field name included: identical. `tests/data/json/` holds
tree-sitter-json's `grammar.json` and its MIT `LICENSE` (the only grammar
vendored so far).

## Build and test

```
M31_ROOT=/path/to/m31-release LANGC=/path/to/m31c bash tests/test.sh
```

Uses the public m31 release v0.14.2. Checks `m31c -fmt --check`, `m31c -lint`,
and every `tests/t_*.m31`. `tests/bench.m31` (not run by `test.sh`) prints
load times: `bench GRAMMAR.json [TEXT]`. Regenerating the oracle dumps needs nvim
and a parser built from the same revision as the grammar:
`GROVE_PARSER_DIR=/dir/with/json.so bash tests/oracle/refresh.sh`.

## Layout

Follows the m31 project layout (`docs/project-layout.md` in the m31 repository):

```
deps                 project file (name grove, version 0.0.1)
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
