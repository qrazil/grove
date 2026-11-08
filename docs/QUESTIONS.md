# Questions for the owner

## Answers (owner, 2026-11-09)

All recommendations below are **approved**, with two changes: the large-file
cutoff `treesitter_maxfile` defaults to **5 MB** (not 2 MB), together with a
long-line threshold, both options (parsing is time-sliced anyway); and
first-open background table builds are fine, with shipped caches only as a later
optimisation. The repository `qrazil/grove` exists (public, branch `main`). A
separate `grove-grammars` repository is approved by name and will be created when
vendoring starts. g1's measurements (SPEC 14.2) made the cache a smaller question
than expected: tables build in under half a second for json, lua and c.


Each question has the recommendation I would act on if you do not answer. Numbers
refer to `SPEC.md` sections. They are ordered by how much they block.

## 1. Parsing algorithm

**Build LR/GLR tables from grammar.json at load time (tree-sitter's own shape)
and cache them on disk, rather than PEG, Earley or hand-written parsers? (SPEC 3)**
Recommendation: yes. It is the only option under which `prec`, `prec.left/right`,
`prec.dynamic` and `conflicts` mean what the grammar authors meant, it gives
tree-sitter's incremental reuse for free, and the LR(0) experiment shows the
automata are small enough (50 states for json, 1 128 for C, 5 316 for
typescript, 15 858 for sql, built in under a second even in Python). What it
costs is a table generator written in m31 (the unmeasured part) and exactness
work against the oracle. PEG stays only as the g0/g1 test vehicle.

## 2. First-open build time

**Is it acceptable that the first time a language is opened its tables are built in
the background (seconds, up to tens of seconds for cpp, kotlin, sql), with the
lexical highlighter used meanwhile, and cached under `~/.cache/grove` after? (SPEC 3.7)**
Recommendation: yes. The alternative is to ship the cache as a build artifact
(content-addressed by sha256 of grammar.json plus a format version); that is
still "grammar as data" because it is derived and regenerable. Decide after g2
measures the real build time; if cpp exceeds a minute, ship artifacts.

## 3. Memory and file-size budget

**How much memory may grove use, and above what file size does it stand down?
(SPEC 3.6, 5.1, 9.1)**
Recommendation: per-language tables up to ~20 MB (only the languages with open
buffers are resident); ~50 bytes per node worst case; the option
`treesitter_maxfile` default **2 MB** (above it the buffer keeps the `syntax`
highlighter and no tree is built), plus a long-line guard.

## 4. Which languages, in which order, and which scanners to port

**Confirm the tiers. (SPEC 6.2, GRAMMARS.md)**
Recommendation:
- tier A (no scanner or an easy one; g1-g4): json, diff, lua, toml, css, make,
  c, go, java, cpp, sql;
- tier B (medium scanners; after g5): javascript, typescript, tsx, rust, python,
  html, dockerfile, kotlin;
- tier C (the scanner is the language; maybe never): bash, yaml, markdown,
  markdown_inline. Keep them on the `syntax` library, which already has
  dedicated markdown and yaml modes. markdown_inline is meaningless without
  markdown, so both go together or not at all.

First real language after json: **lua, then c** (lua is small and has a
scanner of the simplest kind; c is the realistic target with no scanner at all).

## 5. Which queries are the primary family

**Highlights, injections, indents, folds, textobjects exist in two incompatible
families here: nvim-treesitter (`@indent.begin`, `#lua-match?`, `#offset!`, no
textobjects) and Helix (`@indent`, `#match?` regex, `#not-same-line?`, no folds
for most). Which one is primary, and may queries be vendored? (SPEC 7.2)**
Recommendation: nvim-treesitter's for highlights, injections, folds and indents
(full coverage of the 23: 23, 22, 21 and 17 files), Helix's for textobjects
(the only source: 16 languages), each kept unmodified in its own directory with
its notice. Licences: nvim-treesitter Apache-2.0 (checked earlier in m3's
`TREE-SITTER.md`), Helix MPL-2.0 per file (recorded there as "to verify";
verify before vendoring). The Q1 subset (SPEC 7.3) then needs `#lua-match?`
(74 uses) and `#offset!` (13). Writing own textobjects/indents later is open.

## 6. Where grammars, queries and their revisions live

**One tuple (grammar.json, node-types.json, queries, oracle parser) per language,
pinned. Which revisions, and in which repository? (SPEC 2.1)**
The machine has two inconsistent sources: nvim-treesitter's `lockfile.json`
(what the owner's nvim runs, and m3's doc names) and the checkouts under
`/home/nox/homelab/apps/nox/runtime/grammars/sources` (different revisions; the
json grammar.json already disagrees with nvim's compiled json).
Recommendation: take nvim-treesitter's lockfile revisions, because the oracle
parsers are the ones nvim already runs; vendor only `grammar.json`,
`node-types.json` and `LICENSE` per language (about 3.5 MB of grammar.json for the 23, node-types.json on top), in a
separate repository (suggested name `grove-grammars`, to be created by the
owner), with `grammars.lock` (name, upstream, revision, licence, sha256). grove
itself vendors only the json grammar used by its tests (done, with its MIT
licence).

## 7. Unicode property tables

**grove needs `\p{L}`, `\p{Nd}`, `\p{Zs}`, `\p{Control}`, `\p{XID_Start}`,
`\p{XID_Continue}` (SPEC 1.9, 2.4). The standard library's `unicode` module has
none. Generate range tables from the Unicode data into a grove module, or ask
the m31 project for a general-category and XID API?**
Recommendation: generate (a script in `scripts/`, tables committed, about
1 KB each range-compressed, Unicode data licence noted) now, and offer the same
tables to m31's `unicode` later. Not blocking: g0 needs them only for cpp, rust,
python, go, java, kotlin, javascript, typescript, tsx and lua.

## 8. Requests to the m31 project

None are blocking. In order of usefulness to grove:
1. the already planned accessor inlining and `const` hoisting (perf board 1-2):
   they decide whether the lexer loop is 3x or 10x slower than C;
2. `Arena<T>`/`Handle` (accepted, not in the tree): grove isolates its arrays
   behind one module so it can switch;
3. an order-preserving JSON object in `json` (or a streaming reader). grove has
   its own, so this is only a duplicated 150 lines.
Recommendation: ask for nothing yet; measure at g1 and then ask with numbers.

## 9. Changes to `MED_ts`

**Two additions to m3's `engine/MED_ts.m31` interface so a parse can never stall
the editor (SPEC 10): `tick(int budget_us)` (let the backend do work from the
idle loop) and a per-document `version(document)` (so highlights can be re-asked
when stale).**
Recommendation: yes. Without them `parse` of a 1 MB file is a stall by
construction. Chain semantics: a backend with no tree yet answers empty lists,
and the chain falls through to the lexical backend.

## 10. Cooperative or threaded parsing

**Time-sliced `pump(budget)` driven by the editor's loop first, a `spawn`ed
worker later? (SPEC 9.2)**
Recommendation: cooperative first: deterministic, testable, no thread handoff.
Move to a worker only if slices show up in m3's key-to-frame measurement. The
flat-array tree makes the handoff cheap if needed.

## 11. How faithful on broken code

**Is "same family as tree-sitter's recovery, not identical trees on erroneous
input" acceptable? (SPEC 8)**
Recommendation: yes. The oracle compares trees only on files tree-sitter parses
without errors; on broken files the metric is the share of bytes under
identical nodes plus "never a trap, never a hang". Chasing identical error
trees would require reproducing the generator's state merging.

## 12. Naming, module prefix, licence

**Repository `qrazil/grove` (prefix `GRV`, which `m31c -lint` accepts), licence?**
The sibling repos (`syntax`, `tui`) carry no LICENSE file. Recommendation: the
same licence as m3 once the owner chooses one; until then grove ships none
(only the vendored tree-sitter-json MIT notice). The parent pushes; I created
no remote.

## 13. Dependencies

**Should grove depend on `syntax` (for the capture to class mapping) or stay
free of it?** Recommendation: stay free; the mapping from capture names to
classes belongs to m3's integration layer (`GRV_med`), where `SYN_class.from_capture`
is already visible, so grove remains a general library.

## 14. Honesty about what is not known

Not measured: the m31 time to build tables for typescript/cpp/kotlin/sql; the
number of distinct valid-token sets per language (lexer count); the memory per
node in practice; the real cost of tree-sitter's `ts_parser_parse` without
nvim's overhead. Not verified: that tree-sitter's generator uses LR(1) with
state minimisation (as I recall) rather than LALR with splitting; how it numbers
and merges identical string and named terminals; the Helix queries' licence.
The plan makes each of these a measurement or an oracle check in g0 to g2 rather
than an assumption.
