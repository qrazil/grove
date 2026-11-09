# grove: specification and feasibility study

Status: **design with a working g1, g2, conflict resolution and the first scanner (0.4.0)**. Written first as a design
(0.0.1); section 14 records what g1 built and measured, and where it changed the
design. Decisions of the owner (2026-11-09): all recommendations of
`QUESTIONS.md` approved, with `treesitter_maxfile` defaulting to **5 MB** (plus a
long-line threshold, both options) and shipped table caches only as a later
optimisation.

How to read the claims. Each fact carries its source:

- **[src]** read in a real source file on this machine (tree-sitter 0.24.7's C
  runtime in `~/.cargo/registry/src/*/tree-sitter-0.24.7/src`, the grammars'
  `grammar.json`, `parser.c` and `scanner.c` under
  `/home/nox/homelab/apps/nox/runtime/grammars/sources/`, the nvim-treesitter
  and Helix query files).
- **[measured]** measured here, with the command in `experiments/` or
  `tests/bench.m31`.
- **[web]** read on tree-sitter's documentation site.
- **[recalled]** from memory of how tree-sitter works. **Not verified.** The
  generator (the Rust crate behind `tree-sitter generate`) is not on this
  machine, so everything about how it builds tables is [recalled] unless
  marked otherwise, and each such point names the check that would settle it.

## 0. Summary

| question | answer |
|---|---|
| Can grove be written in pure m31, no C ABI? | **Yes.** Nothing in the design needs a feature m31 v0.14.2 lacks. The costly parts (table construction, the lexer, the GLR parser) are plain integer-array code. |
| Can it consume `grammar.json` instead of `parser.c`? | **Yes, with work.** Everything `parser.c` holds (tables, lexer DFA) is derived from `grammar.json`; the generator's decisions have to be re-implemented and checked against the oracle. External scanners are the part that is *not* data (section 5). |
| Parsing algorithm | **LR with GLR at declared conflicts, tables built at load time and cached on disk**, tree-sitter's own shape (section 3). Not PEG, not Earley. |
| Largest risks | (1) matching the generator's conflict and lexical resolution well enough that trees are identical; (2) m31 speed on the lexer and parse loops (up to 10x slower than C on byte loops, per the language's own perf board); (3) 7 of the 23 grammars need a hand-written scanner in m31, two of them (yaml, markdown) are large; (4) revision skew between `grammar.json`, queries and the oracle parser. |
| Recommended first language | json (g1), then lua and toml, then c (g4). |
| Cost to the key path | None by design: a one-character edit is a tree update of O(depth) and a re-parse that runs in time slices from an idle tick. |

## 1. Constraints from m31 that shape the design

m31 v0.14.2 (`docs/reference.md` at the tag; read in full for the points below):

1. **No pointers, no unsafe.** Every `type` is a reference-counted heap object;
   `str`, `bytes` and the collections are references (reference 3.2, 7.1).
2. **Reference counting, no GC, a cycle leaks** (7.1). A tree with parent
   pointers is a cycle by construction. Therefore: **a tree is flat arrays and
   integer indices**. The language's cycle design (`m31-wt/cycle-check/docs/
   cycle-check-design.md`) says `Arena<T>` with `Handle` indices is *accepted*
   for graphs that are cyclic on purpose, but states it is "not in the tree"
   yet (v0.14.2 has no `Arena`; `grep Arena` over `docs/` and `lib/` only hits
   the heap-watch design). grove uses `Array<int>`/`List<int>` structure-of-
   arrays behind one module (`GRV_arena`, to be written) so that
   `Arena<T>`/`Handle` can replace the lists when it lands without touching
   callers. A node is an `int`.
3. **`int` is 64-bit signed and traps on overflow** (3.1). There are no
   unsigned or sized integers. Hashes and the like use `wrapping_add/sub/mul`
   (6.5a). Table entries that are 16 bits in tree-sitter are `int`s here, or
   are packed into `bytes` at the cost of shifts (section 3.6).
4. **A `str` is always valid UTF-8** (3.2a), `byte_at` is O(1). A buffer with
   invalid UTF-8 cannot be a `str`; the source for grove is therefore a
   provider of `str` chunks (the editor's lines), never one big `str`, and
   never required to be valid (invalid bytes arrive as U+FFFD from the
   editor's own decoding; grove does not see them).
5. **Hot-path costs.** The language's perf board (`docs/perf-board.md`) records
   `a[i]` as an out-of-line call, ~10x C on SHA-1, and plans inlining;
   `const` is planned to make hoisting legal. Rule for grove, from the owner:
   *big runtime performance hits are not allowed*. So: no interface call per
   byte or per token in the lexer and parser loops; no allocation per token; no
   `Map` in a hot loop; no closures in a hot loop; tables are `Array<int>`
   built once; loops are `for (int i in a .. b)` or `while` over locals.
6. **No exceptions.** Failure is `Result` or a trap; a trap aborts the program
   and a trap in the editor would lose the user's work. Every index into a
   table grove computes must be provably in range, and the loader and the
   query compiler return `Result`.
7. **Threads.** `spawn` runs a function on an OS thread (reference 8.1; the
   release's runtime sources also contain `scheduler.c`, green threads are
   stage 3 of `docs/concurrency-decision.md`, and the surface does not change).
   Values are *moved* across (`send`/`spawn`), with a transitive uniqueness
   check "proportional to the graph, once per crossing" (8.3). A tree that is
   a handful of big arrays is cheap to move; a tree of a million objects is
   not. Another reason for flat arrays.
8. **No augmented assignment, no ternary, no function types, no inheritance**
   (section 9 of the reference). Callbacks are one-method interfaces. Style
   rules from `m31c -lint`: names of 3 or more characters, boolean names start
   with `is_`/`has_`/`can_`/..., a comment of more than one line is a block
   comment.
9. **Stdlib gaps found while writing the prototype:**
   - `json.parse` yields `Object(Map<str, Value>)`, whose order is the hash
     table's (3.9). grammar.json is order-sensitive (first rule = start symbol,
     order of `rules` numbers symbols, order of `externals` numbers scanner
     tokens). grove has its own order-preserving reader (`GRV_json`, 8 ms for
     the 437 KB C++ grammar.json [measured]).
   - `text.regex` is a Thompson NFA over `str` with `find` (unanchored); no
     match-at-offset, no `\p{..}`, no `\b`, no flags. Unusable for a lexer, so
     grove compiles its own (section 2.4, 3.5).
   - `text.unicode` has case folding, graphemes, width, NFC/NFD; it has **no
     general-category or XID query**. Patterns in the grammars use `\p{L}`,
     `\p{Nd}`, `\p{Zs}`, `\p{Control}`, `\p{XID_Start}`, `\p{XID_Continue}`
     [src: counts in section 2.4]. grove needs its own compact range tables for
     these six properties (about 1 KB each once range-compressed [recalled]).
   - `timer.monotonic_ns()` exists (budgeting), `crypto.sha256` exists
     (cache keys), `io`/`fs` exist (cache files, grammar files).

## 2. (a) Loading grammar.json

### 2.1 What is in the file

Top-level keys seen across the 23 target grammars [src, measured by
`experiments/grammar_survey.py`]: `name`, `rules`, `extras`, `conflicts`,
`externals`, `inline`, `supertypes`, `word`, `precedences`, `inherits`,
`$schema`. Notes:

- `rules` is an **ordered** object. The first rule is the start symbol.
- `word` is a string (a rule name) or absent (9 of 23 have none).
- `precedences` is a list of lists of named precedences (listed highest first
  per list [recalled]; present in cpp 2, javascript 7, typescript/tsx 36,
  markdown 3, sql 1). `PREC*` values are either an int (about 830 uses) or such a
  name (about 195 uses).
- `inherits` is set in cpp (`"c"`); the cpp grammar.json is already **merged**
  (312 rules, including C's), so grove does not follow `inherits` [src: rule
  count]. Treat the field as informational.
- Newer tree-sitter versions add a `reserved` construct (RESERVED rule,
  reserved word sets) [recalled; **not present** in any of the 23 snapshots,
  nor in `PATTERN.flags`, which upstream defines but no snapshot uses]. The
  loader refuses an unknown rule type with a message naming it, so a newer
  grammar fails loudly instead of parsing wrongly.
- **Revision skew is real.** The `grammar.json` of tree-sitter-json on this
  machine and nvim-treesitter's compiled json parser (revision 46aa487b) are
  different revisions: the first nests `escape_sequence` inside
  `string_content`, the second does not [measured: both parsed the same text
  with the oracle script]. A `grammar.json` only describes the parser built
  from it. Consequence: grove pins `(grammar.json, queries, oracle parser)` as
  one tuple per language in a manifest (`grammars.lock`: name, upstream URL,
  revision, licence, sha256 of grammar.json, query provenance), and the oracle
  refuses to compare across tuples (`GROVE_PARSER_DIR`).

### 2.2 Rule types and what each becomes

The 16 rule types, with the number of occurrences in the `rules` of the 23
grammars (10 018 SYMBOL, 6 438 STRING, 4 373 SEQ, 4 151 CHOICE, 2 785 FIELD,
1 896 BLANK, 1 244 PATTERN, 1 178 ALIAS, 791 REPEAT, 408 PREC_LEFT, 315 PREC,
251 IMMEDIATE_TOKEN, 218 PREC_RIGHT, 208 REPEAT1, 156 TOKEN, 88 PREC_DYNAMIC)
[measured, `experiments/grammar_survey.py`]:

| rule | meaning | grove |
|---|---|---|
| `STRING` | literal text | a terminal. Anonymous node named by its text, unless the same text is the whole body of a named rule (then one terminal serves both; **[recalled, check]**: compare `ts_symbol_names`/`ts_symbol_metadata` in `parser.c` for rules such as `true: 'true'`) |
| `PATTERN` | a regex (`value`, optional `flags`) | compiled to an automaton at load time (2.4) |
| `SYMBOL` | reference to a rule or an external token | resolved at load time: a rule if one has that name, else an external (`externals` order = scanner token index). Done in the prototype (`GRV_grammar.lower`) |
| `SEQ`, `CHOICE`, `BLANK` | structure | flattened into productions: a CHOICE inside a SEQ is a cross product (the generator does this [recalled]); a guard on blow-up is required (the prototype's LR(0) experiment flattened all 23 grammars without trouble, largest sql 7 529 productions) |
| `REPEAT`, `REPEAT1` | iteration | auxiliary rules `aux_sym_X_repeatN` (these names are visible in json's `parser.c` [src]); repeated nodes are hidden and **balanced** after reduction so long lists stay shallow (tree-sitter keeps `repeat_depth` in the subtree and has `ts_subtree_balance` [src]) |
| `FIELD` | name a child | a per-production map `(production id) -> [(field, child index, inherited)]`, not a node |
| `ALIAS` | rename (`value`, `named`) | a per-production alias for a child; `named: false` makes it anonymous |
| `TOKEN` | the content is one lexical token (regex-like sub-grammar) | content compiled as a lexical rule (2.4); `PREC` inside it is *lexical* precedence |
| `IMMEDIATE_TOKEN` | token with no leading extras | a lexical rule flagged "no skipping before"; matters for string contents, template chars, attribute values |
| `PREC`, `PREC_LEFT`, `PREC_RIGHT` | static precedence and associativity on a production | used only to resolve shift/reduce and reduce/reduce conflicts at table build time (3.3); `value` is an int or a name resolved through `precedences` |
| `PREC_DYNAMIC` | run-time tie-break between GLR versions | kept on the production, summed into the subtree and compared when versions merge (`dynamic_precedence` is a subtree field [src]) |

Top-level lists:

- `extras`: tokens (usually whitespace pattern + comments) allowed between any
  two tokens. They may be named rules (comments become nodes) or anonymous
  patterns (whitespace is skipped without a node).
- `conflicts`: groups of rules whose ambiguity is intentional: the table keeps
  both actions and the parser forks (GLR).
- `externals`: tokens produced by the external scanner (section 5).
- `inline`: rules substituted into their uses before table construction (they
  do not exist in the tree).
- `supertypes`: rules that are abstract categories; hidden in the tree, usable
  in queries as `(expression/binary_expression)` [web: supertypes are hidden
  but queryable].
- `word`: the keyword-extraction token, normally `identifier` (2.5).

### 2.3 Pipeline (the generator's passes, as I understand them)

[recalled; the Rust generator is not on this machine. The pass names are the
ones I remember from its `prepare_grammar` module: intern symbols, extract
tokens, expand repeats, flatten, extract default aliases, process inlines.
The semantics below are what the outputs in `parser.c` imply, which I can
check.]

1. read JSON (ordered) and lower to a rule arena (done, prototype);
2. intern: resolve every SYMBOL to a rule index or an external index;
3. extract tokens: every STRING/PATTERN/TOKEN/IMMEDIATE_TOKEN becomes a
   terminal; terminals are numbered by first appearance in rule order
   (**checked on json**: `{ , } : [ ] "` then `string_content_token1`,
   `escape_sequence`, `number`, `true`, `false`, `null`, `comment`, then the
   non-terminals `document`, `_value`, ... then `aux_sym_*` [src: json
   `parser.c` enum]);
4. process inlines, expand repeats into aux rules, flatten SEQ/CHOICE into
   productions, attach precedence, associativity, dynamic precedence, field
   and alias maps;
5. build the parse tables (3.3) and lexer (3.5), compute per-state valid
   terminal sets;
6. serialize (3.7).

### 2.4 Patterns

The regex features that occur in the 1 244 PATTERN rules of the 23 grammars
[measured, `experiments/grammar_survey.py`]: character classes (1 083),
`\d \w \s` (123), `{n,m}` (65), `.` (66), `\p{..}` (21 patterns; only L, Nd,
Zs, XID_Start, XID_Continue, Control), `\u`/`\U` hex escapes (18), `(?:` (3).
**No lookahead, no lookbehind,
no backreferences, no `\b`, no flags in any snapshot.** So a compact regex
dialect (the prototype's `GRV_lex` covers all of this except `\p`, `\u`) is
enough, and compiles to an NFA over **code points** (the prototype matches
bytes; the real lexer must work on code points: classes such as
`[^\n]` must consume a whole UTF-8 sequence). Code-point classes become sorted
range sets; the NFA is turned into a DFA by subset construction (3.5).

### 2.5 What is lost compared with parser.c

`parser.c` holds the generator's *decisions*. grove must reproduce them, and
where it cannot it will differ. Be explicit:

| in parser.c | in grove | consequence |
|---|---|---|
| parse tables after conflict resolution and **state merging/minimisation** | recomputed (3.3) | valid parses unaffected. Error recovery explores states, so on erroneous input trees may differ from tree-sitter's even when everything else is identical (3.4, 8). Also `parse_state` values differ, which is fine because they are never exchanged |
| **lexical conflict resolution**, baked into per-state lex DFAs | recomputed: among tokens *valid in the current parse state*, higher lexical precedence, then longest match, then string over regex, then earlier terminal [web: the five criteria, in that order; context-aware lexing is criterion zero] | exact replication needs the same terminal numbering (3.3 above) and the same implicit precedences (e.g. IMMEDIATE_TOKEN, keyword extraction). Oracle-checked per language |
| lex modes: one lex state per parse state, **merged** where compatible | one lexer per distinct *valid-token set*, built lazily (3.5) | equivalent behaviour, different state numbers |
| keyword extraction table (`ts_keyword_lex_fn`) | rebuilt from `word` | a keyword is only a keyword where the parse state accepts it; otherwise it lexes as `word` |
| external scanner | **code, not data** | section 5 |
| `\p{..}` classes as pre-expanded code point ranges | need Unicode tables in m31 | stdlib gap (1 item 9) |
| field maps, alias sequences, production ids, `non_terminal_alias_map`, supertype map | recomputed | node-types.json is available and used as a cross-check (every `(type, named, fields, children)` entry must be consistent with what grove builds) |
| `ts_primary_state_ids`, small/large state split, compressed tables | irrelevant | grove picks its own packing (3.6) |
| LANGUAGE_VERSION / ABI | irrelevant | grove reads JSON; ABI 13 and 14 grammars both occur in the snapshots [src] |

## 3. (b) Parsing algorithm: options, costs, recommendation

### 3.1 Facts to size the problem

tree-sitter's own tables for the 23 grammars [src: `parser.c` defines,
`experiments/table_sizes.py`]:

| language | LR states | symbols | large states | dense table as u16 |
|---|--:|--:|--:|--:|
| json | 32 | 25 | 3 | ~0 KB |
| lua | 262 | 137 | 2 | ~0 KB |
| c | 1 466 | 266 | 382 | 198 KB |
| javascript | 1 576 | 256 | 293 | 146 KB |
| python | 2 819 | 270 | 189 | 99 KB |
| rust | 3 649 | 346 | 1 014 | 685 KB |
| typescript | 4 345 | 368 | 995 | 715 KB |
| bash | 7 671 | 280 | 528 | 288 KB |
| cpp | 8 838 | 552 | 2 365 | 2.5 MB |
| kotlin | 12 324 | 357 | 6 078 | 4.2 MB |
| sql | 14 876 | 721 | 360 | 506 KB |

(other languages in GRAMMARS.md; "large states" are the ones stored as a dense
row, the rest are sparse in `ts_small_parse_table`). The 12 324 states of
kotlin against 190 rules is the outlier: kotlin has 26 declared conflicts and
no `inline`.

**LR(0) item-set experiment** (`experiments/lr0_estimate.py`, a throwaway
Python script, not the generator): flatten grammar.json as in 2.3, count
productions and LR(0) automaton states (kernel sets, no lookahead, no
conflict handling):

| language | productions | LR(0) states | tree-sitter states |
|---|--:|--:|--:|
| json | 34 | 50 | 32 |
| c | 667 | 1 128 | 1 466 |
| javascript | 632 | 1 192 | 1 576 |
| python | 678 | 1 084 | 2 819 |
| rust | 1 697 | 2 906 | 3 649 |
| typescript | 2 640 | 5 316 | 4 345 |
| cpp | 2 302 | 3 546 | 8 838 |
| bash | 1 482 | 1 907 | 7 671 |
| kotlin | 1 863 | 2 390 | 12 324 |
| sql | 7 529 | 15 858 | 14 876 |

Reading: the LR(0) automaton is built in under a second even in Python for
every grammar, and tree-sitter's final state count is between 0.8x and 5x the
LR(0) count (json and typescript fewer, python 2.6x, bash 4x, kotlin 5x). That
spread is the cost of lookahead-driven state splitting (LR(1) rather than
LALR) and of the GLR conflicts. It means **a table generator in m31 is not
infeasible in size**; what it costs in time is not measured (the real work is
lookahead sets, conflict resolution and the lexer, not the LR(0) automaton).
The m31 runtime is slower than C; assume tens of seconds for the largest
grammars on first build, which is why section 3.7 caches tables.

### 3.2 Measured baseline: what tree-sitter does here

nvim 0.11.5 with nvim-treesitter parsers, injections off, 20 one-character
edits in the middle of the file, `experiments/ts_bench.lua` [measured]:

| file | bytes | cold parse | nodes | edit + reparse (avg / worst) |
|---|--:|--:|--:|--:|
| JSON (generated) | 1.73 MB | 341 ms | 846 003 | 15.6 / 16.5 ms |
| C (libbpf.c x4) | 1.54 MB | 317 ms | 424 509 | 22.7 / 28.4 ms |
| Python (Cython ExprNodes.py) | 0.60 MB | 111 ms | 128 444 | 2.0 / 4.8 ms |
| Rust (core/slice/mod.rs) | 0.22 MB | 30 ms | 41 016 | 12.3 / 15.2 ms |

Honest reading: tree-sitter parses at ~3 to 5 MB/s; an incremental edit in
nvim costs 2 to 28 ms, *not* "below a few ms", and that includes nvim's
`LanguageTree` bookkeeping, which I did not separate from `ts_parser_parse`.
With injections on (nvim's default `parse(true)`) the C case rose to 154 ms per
edit, because each comment/doc injection is reparsed. Lessons for grove: the
"edit under a few ms" goal is tight even for the reference; **injected regions
must be parsed lazily and only for the visible range**.

### 3.3 Options

**A. LR/GLR tables at load time (tree-sitter's shape).** Generate parse tables
from the productions: LR(0) automaton, lookahead (LALR via DeRemer-Pennello or
LR(1) with Pager's weak-compatibility merging, to avoid LALR-only
reduce/reduce conflicts), resolve conflicts by static precedence/associativity,
keep the ones named in `conflicts` as multiple actions, and parse with a
graph-structured stack that forks on them. Dynamic precedence and cost choose
between forks. Whether tree-sitter does LR(1)+minimisation or something
close to LALR is **[recalled: LR(1) item sets then minimisation of compatible
states; unverified]**. The target is "same trees", not "same tables".

- Cost: table build (seconds, once, cached); memory O(states x symbols) worst
  case, in practice the sizes above (section 3.6 turns them into m31 bytes);
  parse time O(n) with a small constant per token.
- Incremental reuse is natural (tree-sitter's design, 4).
- Error recovery is the established algorithm (8).
- Fidelity: highest. The grammars are written against LR semantics: `prec`,
  `prec.left`, `conflicts`, `prec.dynamic` mean exactly this.

**B. Earley / GLL / GLR-without-tables.** No generation step; handles every
CFG. Cost: per-token work grows with ambiguity (Earley O(n^3) worst, O(n) for
unambiguous LR(k)-like grammars but with a large constant: set of items per
position, ~100s of items per token for C++). Memory per position is the item
set, which makes a 1 MB file a hundreds-of-MB structure unless pruned. Static
precedence is not natural in Earley (disambiguation filters are bolted on), so
trees will differ from tree-sitter where grammars lean on `prec`. Incremental
Earley exists in research, not as a known quantity here. Rejected as primary:
slower per token and weaker fidelity.

**C. PEG with precedence climbing / packrat.** Needs no tables and is
trivial to interpret straight from the rules, which is why the prototype uses
it. Measured: 113 KB of JSON in 255 ms (0.44 MB/s) with the unoptimised
position-set matcher [measured, `tests/bench.m31`]; with a DFA lexer and
memoisation it would be several times faster, still slower than A. Fatal for
the general case: ordered choice is not CFG choice; left recursion (every
expression grammar) needs transformation; `conflicts` has no meaning; `prec`
must be re-derived into precedence climbing per rule family automatically,
which is not decidable in general from `grammar.json`. It would work for
json, toml, diff, dockerfile and a few more, and be wrong for typescript.
Rejected as primary. Kept as the g0/g1 test vehicle.

**D. Hand-structured resilient parsers** (rust-analyzer style: a hand-written
recursive-descent parser per language that never fails and produces an
event stream). Best error behaviour, fastest, but it is not "consume existing
grammars as data" at all: 23 hand-written parsers. Out of scope for the stated
goal, but it is the right answer for the *fallback layer* the editor already
has (the `syntax` library) and for languages without a grammar.

**E. Layered hybrid.** A is the engine; when the time slice runs out, or the
file is over the size threshold, the editor keeps the lexical highlighter
(`syntax`), and a partial tree (prefix of the file) is exposed as it grows
(8.4, 9). Not an alternative algorithm, a service level.

### 3.4 Recommendation

**A, built as: LALR(1) with state splitting on conflict (Pager) or canonical
LR(1) merged, precedence resolution as tree-sitter documents it, GLR on
declared conflicts, tables built at load time by a background task, cached on
disk, with an in-process lazy fallback for states.** In order of work:

1. g1: LR(0) + SLR/LALR lookahead, enough for json, toml, lua; GLR stack with
   a single version (no conflicts yet);
2. add conflict resolution by precedence, then declared conflicts + versions;
3. add Pager-style splitting only if an LALR-only reduce/reduce conflict
   appears on a real grammar (to be measured, not assumed);
4. the lexer is built from the same valid-token sets (3.5).

Open and unmeasured: the real build time in m31 for typescript and cpp. g2's
exit criterion includes measuring it; if cpp exceeds a minute, section 3.7's
cache becomes a shipped artifact instead of a local one, which is still
"grammar as data" (derived data, regenerable, content-addressed).

### 3.5 Lexer design (shared by every option)

Context-aware: the parser state determines the **set of valid terminals** (plus
extras, plus externals). A lexer is built per distinct valid set, lazily:

1. all terminals have NFAs (STRING = chain, PATTERN/TOKEN = Thompson), over code
   points; IMMEDIATE_TOKEN differs only by "do not skip extras first";
2. for a valid set V, subset-construct a DFA over the NFAs in V; accepting
   states carry the terminal chosen by the criteria of 2.5 (lexical
   precedence, longest, string over regex, order);
3. DFA transitions are sparse: per state a sorted list of (low, high, next)
   ranges; ASCII gets a 128-entry dense row. Lookup is a table load for ASCII,
   a binary search otherwise;
4. `word` handling: if the DFA picks the `word` terminal and V contains a
   keyword string the text equals, return the keyword; keywords are matched by
   a hash lookup keyed on the match (the syntax library's blob+hash code is the
   model);
5. cache by V's id: `lex_for(valid_set_id)`. In tree-sitter, lex states are
   per parse state and merged, so the count of distinct V is the count that
   matters; unknown here, expected hundreds, **measure in g1**;
6. on no match: error token consuming one code point (8.2).

Cost per token: a handful of table loads per byte. This is the loop that must
be tight in m31 (5).

### 3.6 Table representation in m31

An `Array<int>` entry is 8 bytes. tree-sitter's cpp tables as u16 are ~2.5 MB
dense plus the sparse part; as `Array<int>` that is ~10x. Plan:

- **row-sparse by default**: per state, a sorted run of (symbol, action) pairs
  in one `Array<int>`, action packed in one int (kind 2 bits, target 30 bits,
  production/precedence payload in the rest); lookup by binary search over the
  run, or a direct 128-entry row for hot states (the "large states" idea);
- optional `bytes`-packed form (2 bytes per entry via `b[i] | b[i+1] << 8`) if
  memory matters more than speed; measure before choosing;
- one table per language, built or loaded when the first buffer of that
  language opens, released when the last closes.

Expected memory (entries x 8 bytes, order of magnitude only): c ~1 MB, python
~1 MB, typescript ~6 MB, cpp ~12 MB, kotlin ~20 MB, sql ~8 MB. Acceptable for a
desktop editor if one language is hot at a time; the owner decides the budget
(QUESTIONS).

### 3.7 Table cache

The cache key is `sha256(grammar.json bytes) + grove table-format version`
(`lib/crypto/sha256.m31` exists). The file is the table `Array<int>`s plus the
production, field, alias and lexer tables, written as little-endian words via
`bytes`. A cache hit makes load = read + validate; a miss builds in a spawned
task and the editor runs lexical fallback meanwhile. The cache directory is
`$XDG_CACHE_HOME/grove/` (or `~/.cache/grove`); it is derived data and can be
deleted at any time.

## 4. (c) Incremental reparse

The model is tree-sitter's, and the relevant part of the runtime was read
[src: `parser.c` 746-820, `subtree.h`, `get_changed_ranges.c`, `api.h`].

### 4.1 Representation that makes it possible

Each node stores **padding** (bytes of whitespace/extras before its first
token) and **size** (bytes of its own span), *relative*, not absolute offsets
(tree-sitter's `Subtree` has `padding` and `size`, plus `lookahead_bytes`,
`parse_state`, and flags `has_changes`, `fragile_left/right`, `is_missing`,
`depends_on_column` [src]). Absolute positions are the sum along the path from
the root. Consequence: an edit changes only the nodes on the path to the edit;
everything after it is unchanged *and not touched*, because its offset is
implied. An absolute-offset arena would need an O(n) shift on every edit: not
acceptable.

Persistent structure: a new tree is new nodes for the changed spine plus shared
unchanged subtrees. In the flat arena this means **nodes are immutable once
published, a version is a root index, and old versions are reclaimed by
copying the live tree into a fresh arena when garbage exceeds a threshold**
(a generational compaction pass; also what makes handing a tree to another
thread cheap and unique).

### 4.2 Edit

`edit(start_byte, old_end_byte, new_end_byte)` (plus rows/columns for the
editor):

1. update the line table (prefix sums; lazily, or a Fenwick tree);
2. walk root -> leaf along the edit; for every node on the path make a copy
   with adjusted padding/size and `has_changes = true`;
3. also mark nodes whose **lookahead** reaches the edit: a leaf whose
   `lookahead_bytes` extends into the edited range is invalid even if it ends
   before it (the lexer peeked past its end; tree-sitter stores exactly this);
4. cost: O(depth + siblings scanned per level); a long hidden repeat list is
   rebalanced so this stays logarithmic.

### 4.3 Reparse with reuse

The parser takes the old tree through a *reusable node* cursor and, at each
position, offers the next token or a whole subtree. Conditions to reuse a
subtree at byte position `p` [src: `ts_parser__reuse_node`]:

- the node starts exactly at `p` (skip past nodes that end before, descend
  into larger ones);
- the **external scanner state** before it equals the current one;
- it has no changes, is not an error, is not missing, is not **fragile**
  (built while the parser had multiple versions or via an error repair, so its
  structure may depend on context);
- (included ranges equal, used for injections);
- its first leaf is lexically compatible with the current parse state:
  `ts_parser__can_reuse_first_leaf` (the token the node starts with must be
  the one the lexer would produce in this state).

If reused, the parser shifts the whole subtree: one table lookup (goto on the
node's symbol in the current state) replaces all the work inside it. Else it
descends one level and retries; at a leaf it lexes normally.

grove implements the same conditions, in the same order, with the same flags.
Reuse correctness is checked by the oracle in the strongest form available:
**for any edit script, `incremental(edit(old))` must equal `from_scratch(new)`
node for node**, including after error-producing edits (tests, section 11).

### 4.4 After the parse

`changed_ranges(old, new)` returns the byte ranges whose structure changed
(tree-sitter: `ts_tree_get_changed_ranges`), used to invalidate highlight,
fold and indent caches and to tell the editor which rows to redraw. The
highlight cache is keyed on node ids' version; unchanged subtrees keep their
cached captures.

### 4.5 Cost

Reparse after one character: O(depth) edit + re-lex of the damaged token(s) +
a reduce chain up to the first reusable boundary + reuse lookups. The expected
cost is a few dozen tokens for a local edit. The cases that are expensive in
tree-sitter are expensive here too: an edit that changes the lexical context
of the rest of the file (opening a block comment or a string, a raw-string
delimiter, a heredoc) forces re-lexing to where the context closes, because
the reused tokens fail `can_reuse_first_leaf`/scanner-state checks. That is
the rust 12 ms case above (doc comments) and the python/yaml indentation
cases; the time-sliced reparse (9) bounds the effect on the editor.

## 5. (d) The tree

### 5.1 Shape

Per node, packed into integers in structure-of-arrays form (names are
indicative):

| field | bits | note |
|---|--:|---|
| `symbol` | 16 | terminal or non-terminal id; aliases are stored on the parent's production (visible type = `alias` if present) |
| flags | ~10 | `visible`, `named`, `extra`, `missing`, `error`, `fragile_left`, `fragile_right`, `has_changes`, `has_external_state`, `depends_on_column`, `is_keyword` |
| `child_count` | 24 | |
| `padding`, `size` | 2 x 28 | bytes; sources over 256 MB are refused |
| `parse_state` | 16 | for reuse |
| `lookahead_bytes` | 16 | capped |
| `error_cost`, `dynamic_precedence` | 32, 16 | |
| `production_id` | 16 | -> field map and alias map |
| `first_child` | 32 | index into the shared `kids` array (children are contiguous) |
| external state | 32 | index into a blob table (the scanner's serialized state), only for external tokens |

Leaves are two integers (symbol+flags+state+lookahead / padding+size); parents
four plus 8 bytes per child. Expected: ~16 B per leaf and ~40-50 B per parent;
tree-sitter's own counts for the baseline files (424 509 nodes for 1.5 MB of C
[measured]) would be ~15-20 MB here. Order of magnitude only; measure at g2.

### 5.2 Access

- **Node = `int`.** No per-node object; the API is on the tree
  (`tree.kind(node)`), plus a `Cursor` object (mutable: `goto_first_child`,
  `goto_next_sibling`, `goto_parent`, `goto_first_child_for_byte`, tracks the
  running byte offset; hidden nodes are skipped by the cursor, as in
  tree-sitter), and bulk queries that return flat `List<int>` (triples of
  start, end, capture id) like the `syntax` library's spans. No allocation per
  node on a traversal.
- **Fields**: `child_by_field(node, field_id)` and `field_of_child(node, i)`
  via the production's field map; fields are inherited through hidden nodes as
  in tree-sitter [recalled; test with the oracle's `field:` output, which
  already exercises it on `key:`/`value:`].
- **Named vs anonymous**: named = produced by a rule or an `ALIAS(named: true)`;
  anonymous = literal tokens. Hidden = name starts with `_` (or is an aux
  repeat, or an inlined/supertype node). The oracle dumps named nodes only; a
  second dump mode with anonymous nodes comes with g2.
- **Ranges**: `start_byte(node)`, `end_byte(node)` computed by cursor offset;
  `start_point/end_point` (row, byte column) via the line table
  (O(log lines)). Columns are *bytes*, as the editor's buffer uses (MED_ts
  positions are "0-based rows and byte columns").
- **ERROR / MISSING** nodes: `(ERROR ...)` wraps skipped content;
  `(MISSING x)` is a zero-width inserted token.
- **Zero copy**: the tree never holds text. Node text is read from the
  `Source`. The source is a provider of `str` chunks (the editor's lines), with
  a line table; the lexer holds the current chunk and indexes it with
  `byte_at` (O(1), not an interface call per byte: the interface is called
  once per chunk). Nothing copies the buffer into one big string.

## 6. (e) External scanners

### 6.1 What they are

An external scanner is C code (`scanner.c`/`scanner.cc`) that tree-sitter's
lexer calls *before* its own DFA when the current parse state accepts at least
one external token. It receives the lexer (lookahead character, `advance`,
`mark_end`, `result_symbol`, `eof`, `get_column`) and the **set of valid
external tokens** (`valid_symbols`), and returns whether it produced one. It
keeps state that is serialized to a byte buffer (at most 1024 bytes: `TREE_SITTER_SERIALIZATION_BUFFER_SIZE` [src: parser.h:14]) on every
external token and restored on re-use/backtracking: that is what makes it
incrementally safe, and the serialized state is what the reuse check compares
(4.3).

### 6.2 Which of the 23 have one

From `scanner.c`/`.cc` on this machine [src; sizes by `wc -l`]. "externals" is
the number of external tokens in `grammar.json`:

| grammar | externals | scanner LOC | state | what it does |
|---|--:|--:|---|---|
| c | 0 | none | | |
| go | 0 | none | | (statements end at a `"\n"` or `";"` STRING token of the grammar itself; the whitespace extra `\s` also matches newlines, so this works only because the lexer is **context-aware**: where a terminator is valid, `"\n"` wins over the extra. A good illustration of why section 3.5 lexes per valid-token set) |
| java | 0 | none | | |
| json | 0 | none | | |
| make | 0 | none | | |
| diff | 0 | none | | |
| css | 1 | 52 | none | `_descendant_operator`: whitespace between selectors counts as the descendant combinator only when followed by something that starts a selector; has a look-ahead scan for `{` after a `:` to tell `a :hover` from `a: b`. **Trivial** |
| toml | 5 | 91 | none | end of multi-line basic/literal strings (`"""`, `'''` with up to two quotes allowed before the closer) and line-ending-or-EOF. **Easy** |
| cpp | 2 | 148 | delimiter (<=16 chars) | raw string literals `R"delim( ... )delim"`: start tag then content until `)delim"`. **Easy** |
| javascript | 3 | 187 | none | `_automatic_semicolon` (ASI: newline + next token cannot continue, with `}`/EOF rules), `_template_chars` (template string text up to `${` or backtick), `_ternary_qmark` (`?` that is not `?.`/`??`). Stateless but needs lookahead over whitespace and comments (it scans `/* */` and `//` itself). **Medium** |
| typescript, tsx | 5 | 228 (shared `common/scanner.h` 217 + 11) | none | the JavaScript three plus `||` (for a `||=`/`||` ambiguity) and `_function_signature_automatic_semicolon`. **Medium** |
| lua | 6 | 194 | level of `[==[` (1 byte) | long strings and long comments `--[==[ ... ]==]`: start counts the `=`s, content runs to the matching close, end. **Easy** |
| sql | 3 | 189 | dollar-quote tag (heap string) | PostgreSQL `$tag$ ... $tag$` strings: start tag, content, end tag. **Easy** (state is a string) |
| rust | 10 | 393 | hash count (1 byte) | raw strings `r#"..."#` (start/content/end), string content, **float literals** (so `1.` vs `1..2` vs `1.foo`), outer/inner doc-comment markers `///` `//!` and doc content, **nested block comments** `/* /* */ */` with doc markers. **Medium-hard** (many small, tricky pieces) |
| kotlin | 7 | 543 | stack of string delimiters (<=serialization buffer) | `_automatic_semicolon`, import-list delimiter, `?.` safe navigation, **nested** multiline comments, string start/end/content with `${}`/`$name` interpolation and triple quotes (code is "copy-pasted" from JavaScript's and Julia's scanners per its own comment). **Medium-hard** |
| python | 12 | 528 | indent stack + string-delimiter stack | `_newline`, `_indent`, `_dedent` (offside rule with a stack of indent widths; tabs counted as 8 by default; inside brackets newlines are ignored), f-string/str start, content, end with prefix flags (raw, bytes, format, triple) and `{`-interpolation handling, `escape_interpolation`, plus the "error-recovery" externals `]`, `)`, `}`, `except` that exist so the parser can recover from unclosed brackets. **Hard** (offside rule + string states) |
| dockerfile | 5 | 318 | heredoc list | `<<EOF` heredocs inside `RUN`/`COPY`: marker, line, end marker, newline, and an error sentinel. **Medium** |
| html | 9 | 362 | stack of open tags | start-tag names (and which are `script`/`style`), end-tag names, **implicit end tags** (`<p>` closed by `<div>`, void elements via a table), `/>`, raw text for script/style, comments, erroneous end tag. **Medium** |
| markdown_inline | 15 | 397 | a few counters | delimiter-run logic of CommonMark emphasis (left/right flanking via the *previous token's* whitespace/punctuation flags), code spans (matching backtick run lengths), `$latex$` spans, strikethrough, "unclosed span" recovery. **Hard** (CommonMark rules) |
| bash | 29 | 1 217 | heredoc stack, flags | heredocs (`<<`, `<<-`, quoted delimiters, bodies with `$` expansion), file descriptors, `${...}` expansion words and the `#`, `!`, `=` operators, `[[ ]]` test operators, regex after `=~`, extglob patterns, `$` bare, brace expansion start, concat, `esac`. **Very hard** |
| yaml | 105 | 981 (C++) | indent stack + flow/block context + many flags | the YAML 1.2 state machine: the 105 externals encode (context x position) variants such as `_r_blk_key_bgn`, `_br_blk_seq_bgn`, `_b_flw_map_bgn`, plain scalars per context (`_r_sgl_pln_str_blk`, ...), quoted scalars, block scalars, tags, anchors, aliases, document start/end. The scanner *is* the YAML grammar. **Very hard** |
| markdown | 47 | 1 597 | stack of open container blocks, line state | CommonMark **block structure**: block quotes, list items (five marker kinds, each in a "don't interrupt" variant), indented chunks, fenced code (backtick and tilde), ATX/setext headings, thematic breaks, HTML blocks 1-7, front matter (`---`, `+++`), pipe tables, and `block_continuation` matching of open blocks line by line. **Very hard** |

How well each was read: css, toml, cpp, lua, sql, javascript, rust (structure
and entry points), kotlin (header) and dockerfile (state struct) were opened
and skimmed; typescript/tsx share `common/scanner.h`; **python, html,
markdown, markdown_inline, bash and yaml were characterised from their token
lists, state structs and size, not read through**. Their rows are estimates of
what the scanner must do, to be confirmed when each is ported.

Summary: **6 grammars need none, 17 need one**. Easy (a day each): css, toml,
cpp, lua, sql (5). Medium to medium-hard: javascript, typescript, tsx (one
shared scanner), rust, kotlin, dockerfile, html (7 grammars). Hard: python,
markdown_inline (2). Very hard: bash, yaml, markdown (3). In yaml and markdown
"the language's real parser lives in the scanner".

### 6.3 What grove does about them

There is no way to run C. The design: an **external scanner is an m31 object
implementing one interface**, written by hand per language and shipped in
grove's source tree, selected by the grammar's `name`:

```
pub interface Scanner {
    /// Try to produce one of the external tokens marked in `valid`
    /// (valid[i] true = externals[i] acceptable). Returns the token index
    /// or -1, and sets where the token ends through `lex`.
    int scan(ScanLexer lex, Array<bool> valid);   // sketch
    /// The state as bytes (<= 1024), and its inverse.
    bytes serialize();
    void deserialize(bytes state);
}
```

`ScanLexer` is a concrete type (not an interface; no per-character interface
calls) with `lookahead()`, `advance(is_skip)`, `mark_end()`, `column()`,
`is_eof()`, mirroring tree-sitter's `TSLexer`, so the existing C scanners
translate almost line by line. The scanner state is a small `bytes`, so reuse
checks and the tree's `external state` blob table work unchanged.

Porting order follows the milestones: none for json/c/go/java/make/diff
(they work at g4/g5 with no scanner); css, toml, lua, cpp, sql at g4+; then
javascript/typescript, rust, python; html, dockerfile; the five hard ones last
or never (markdown and yaml may stay on the lexical `syntax` highlighter,
which already has dedicated markdown and yaml modes; markdown's inline layer is
also *injected*, so a missing block scanner costs the most).

Note the scanners are not data in the grammar sense, but each is a bounded
piece of code, and the translation can be mechanically checked against the real scanner by the
oracle: run both on the same file and compare token streams, which is a test
we get for free (the oracle's trees would differ at the first scanner bug).

Two hooks can lower the cost: (a) an alternative to the scanner for the
simplest cases where the "scanner" is really a lexical rule the generator
could not express, e.g. toml's multi-line string end: allow per-grammar
`GRV_override` regex patterns; (b) a generic **"indentation scanner"** and a
generic **"heredoc scanner"** with parameters, reused by python/yaml-lite and
bash/dockerfile. Not planned until two ports exist and show the overlap.

## 7. (f) The query language

### 7.1 What exists

S-expression patterns [web, plus `query.c`/`api.h` read]:

- node patterns: `(identifier)`, `(binary_expression left: (_) right: (_))`,
  anonymous `"+"`, wildcards `(_)` named, `_` any, `(ERROR)`, `(MISSING x)`;
- fields `field: pattern`, negated fields `!field`;
- captures `@name` after a pattern;
- alternation `[ a b ]` and groups `( a b )` of sibling sequences;
- quantifiers `+ * ?` on a sibling pattern;
- anchors `.` (immediate sibling / first / last child);
- supertype syntax `(expression/identifier)`;
- predicates `(#eq? @a "x")`, `(#eq? @a @b)`, `#not-eq?`, `#match?` /
  `#not-match?` (regex), `#any-of?`, `#is?`/`#is-not?` (properties such as
  `local`), `#any-eq?`, `#any-match?`;
- directives `(#set! key value)` and editor-defined ones.

[src] In the C library (`query.c`, `api.h`) predicates are parsed into steps
and **left to the binding to evaluate**: the library has `TSQueryPredicateStep`
types (capture, string, done) and no `eq?`/`match?` logic of its own. So the
predicate semantics are whatever the editor says they are: nvim defines
`lua-match?`, `vim-match?`, `has-ancestor?`, `has-parent?`, `contains?`,
`offset!`, `trim!`, `downcase!`, `set-lang-from-info-string!`; Helix defines
`not-same-line?`, `not-one-line?`, `not-kind-eq?`, `set-adjacent!`, `strip!`.

### 7.2 What the real query files use (survey)

[measured: `experiments/query_survey.py`; 23 languages; the files that exist]

| source | files | lines | predicates and directives (count) |
|---|--:|--:|---|
| Helix (`/usr/lib64/helix/runtime/queries`) | 86 | 4 247 | `#set!` 77, `#match?` 50, `#eq?` 23, `#any-of?` 13, `#not-same-line?` 12, `#not-kind-eq?` 10, `#strip!` 2, `#set-adjacent!` 2, `#not-one-line?` 1 |
| nvim-treesitter (`master`, `queries/`) | 99 | 7 116 | `#set!` 205, `#lua-match?` 74, `#eq?` 65, `#any-of?` 57, `#offset!` 13, `#has-ancestor?` 6, `#not-has-parent?` 3, `#not-kind-eq?` 3, `#match?` 3, `#trim!` 3, 5 others once |

Structural features: alternations `[` 289 (helix) / 419 (nvim), field patterns
245/470, anchors `.` 93/152, wildcard `(_)` 107/71, quantified siblings 170/233,
`(ERROR` 7/15, private captures `@_x` 64/203, **negated fields 3/0, MISSING 0/0,
supertype syntax 0/0**. Helix's `#match?` patterns (50) use only anchors,
classes, alternation, `\d \w \s` and Helix's `\A`; **no lookaround, no
`(?i)`, no `\b`, no `\p`** (so the lexer's regex dialect covers them).

Query files that exist for the 23 languages: out of the 23 languages, nvim-treesitter has highlights for 23, folds for 21,
indents for 17, injections for 22, locals for 16; **it has no textobjects**
(`nvim-treesitter-textobjects` is a separate plugin, not installed here).
Helix has highlights for 22 (markdown_inline has an empty directory),
textobjects for 16, indents for 15, injections for 19, locals for 7, folds for
2 (kotlin, lua). For the editor's five features:

| feature | query file | where available here |
|---|---|---|
| highlights | `highlights.scm` | both |
| injections | `injections.scm` | both |
| text objects | `textobjects.scm` (`@function.outer`, `@class.inner`, ...) | **Helix only** |
| indent | `indents.scm` (nvim: `@indent.begin` etc.; Helix: `@indent`, `@outdent`, with `#set! "scope" "all"`) | both, **different dialects** |
| folds | `folds.scm` (`@fold`) | nvim (and 2 in Helix) |

### 7.3 Recommended subset, in order

**Q0 (g3):** node patterns (named/anonymous/wildcard), fields (positive and
`!field`), captures, alternation `[ ]`, sibling groups, quantifiers `? * +`,
anchor `.`, predicates `#eq?`, `#not-eq?`, `#match?`, `#not-match?`,
`#any-of?`, `#not-any-of?`, directives `#set!` (key/value stored on the
pattern), the private capture convention `@_x`. This covers all of Helix's
highlights/textobjects/injections structure and all but a few of nvim's.
Matching: tree-sitter's algorithm is a state machine advanced over a depth-first
walk of the tree, collecting partial matches (`TSQueryCursor`); grove does the
same with `List<int>` states, restricted to a byte range (viewport).

**Q1:** `#lua-match?` (nvim; 74 uses): translate Lua patterns to the regex
dialect at query load (Lua patterns have `%a %d %s %w`, `-` lazy, `^$`; the
used ones are simple), `#offset!`, `#trim!`, `#has-ancestor?`/`#has-parent?`,
Helix's `#not-same-line?`, `#not-one-line?`, `#not-kind-eq?`, `#strip!`,
`#set-adjacent!`; `(ERROR)` patterns; `#is-not? local` with `locals.scm`
(definitions, references, scopes: needed for semantically better highlighting;
optional).

**Q2:** supertype syntax, `(MISSING)`, `#any-eq?`, `#any-match?`, and query
validation against `node-types.json` (typo in a node name = load-time error,
as `TSQueryErrorNodeType`/`Field`/`Capture` in `api.h` [src]).

Highlight capture names are `@a.b.c` in both worlds but differ by editor
(`@keyword.control` vs `@keyword.conditional`); the editor's mapping
(`SYN_class.from_capture`) already exists. **Policy decision for the owner**
(QUESTIONS): which query family is primary.

Priorities and the fallback chain are not the query engine's business.

### 7.4 Execution budget

A cursor has a byte range and a **step budget**; `next_capture()` returns
`None` and `exhausted() == true` when the budget is spent, so highlighting a
viewport can be resumed next tick rather than stall (tree-sitter has
`ts_query_cursor_set_timeout_micros` and a match limit for the same reason
[src: api.h]). Compiled queries are cached per language; compile is a
load-time cost (the nvim-treesitter highlights for c/ts/cpp are the largest
files, ~hundreds of lines) and expected in the low milliseconds.

## 8. (h) Error recovery

### 8.1 tree-sitter's strategy, as far as verified

[src: `error_costs.h`, the constants at the top of `parser.c`, and
`ts_parser__handle_error` / `ts_parser__recover` read in full for structure;
the cost bookkeeping inside `ts_parser__better_version_exists` and friends not
read.]

- Parsing keeps up to `MAX_VERSION_COUNT = 6` stack versions
  (`MAX_VERSION_COUNT_OVERFLOW = 4`); versions that are strictly worse by cost
  are dropped (`MAX_COST_DIFFERENCE = 16 x ERROR_COST_PER_SKIPPED_TREE`).
- Costs: per recovery 500, per missing tree 110, per skipped tree 100, per
  skipped line 30, per skipped character 1.
- `MAX_SUMMARY_DEPTH = 16`: when an error is detected, the parser has recorded,
  for each stack version, a **summary** of the (state, depth) pairs up to 16
  entries deep.
- **`ts_parser__handle_error`** [src, read]: first perform every reduction
  possible in the current state regardless of lookahead; then, **for every
  token symbol** in the language, check whether pushing it as a `MISSING` leaf
  leads to a state with a reduce action on the current lookahead, and if so
  fork a version with the missing token; push an `ERROR_STATE` discontinuity on
  the remaining versions; record the summary (depth <= 16); call
  `ts_parser__recover`.
- **`ts_parser__recover`** [src, its comments read]: two strategies. (1) Find a
  previous state in the summary in which the lookahead would be valid, pop the
  subtrees pushed since, wrap them in an `ERROR` node, and continue from that
  state (not if it creates a redundant version or is clearly worse than an
  existing one). (2) Wrap the lookahead token in an `ERROR` node and move on,
  staying in the error state; adjacent skipped tokens merge into one `ERROR`.
  Strategy 2 is also tried after a successful strategy 1 unless there are too
  many versions. At end of file in the error state, everything is wrapped in a
  single `ERROR`. An extra token met while recovering is marked extra, so it
  does not count in the cost.
- Subtrees built during recovery are `fragile` [src: flag exists and blocks reuse] and are not reused by the next
  incremental parse.

### 8.2 grove's plan

1. g1-g2: stop at the first error with a single `ERROR` node covering the rest
   of the input from the error up to the end (the PEG prototype does the
   equivalent: no tree). Enough for valid files and for the editor to fall back.
2. g2: **panic-mode with the summary**: record (state, depth) pairs as above;
   on error pop to the nearest summary state accepting the lookahead, wrap the
   popped nodes in `ERROR`, else skip a token (one code point if the lexer
   found nothing). Deterministic, cheap, good enough for highlighting while
   typing.
3. g4: add MISSING-token insertion and the multi-version cost competition with
   tree-sitter's constants, so that trees on typical editing errors approach
   tree-sitter's.
4. Always: a hard bound on work per error (versions <= 6, summary depth <= 16,
   skipped chars counted) so a pathological file cannot stall; on exceeding it
   the parse yields a single ERROR node for that region.

### 8.3 How it compares

- Same family, simpler first. Where tree-sitter's lexer returns an error token
  the parser may consume a whole line of garbage cheaply; grove must do the
  same (cost per skipped line) or a file of binary junk is quadratic.
- **Exact equality on erroneous input is not a goal.** The oracle compares
  trees only on files the oracle parser parses without errors (the fixtures);
  for erroneous files the metric is the share of bytes covered by nodes
  identical to tree-sitter's (target >= 90% outside the damaged line for
  single-token damage, to be measured) and "never a trap, never a hang".
- Because grove's states differ from tree-sitter's (merging), the *specific*
  recovery decision can differ even with the same algorithm (2.5). Accepted.

### 8.4 Partial trees

Because parsing is incremental in time (9), the current stack at any pause is
a valid partial tree: completed subtrees followed by the pending tokens. The
editor can use it for the prefix of the file (highlight the first N KB with
the tree while the rest is lexical). This is not in tree-sitter's API and is
cheap for grove.

## 9. (g) Performance budget and cooperative parsing

### 9.1 Targets

| measure | target | rationale and baseline |
|---|---|---|
| key path (edit notification) | **<= 0.2 ms**, O(depth), no parsing | the edit only updates the tree spine and the line table |
| first parse of a 1 MB file | **complete within ~5 s of wall clock in time slices**, never more than **2 ms per slice**; the editor sees a partial tree meanwhile (8.4) | tree-sitter: 0.3-0.5 s (3-5 MB/s) [measured]; m31 may be up to ~10x slower on byte loops (perf board), hence 3-5 s |
| reparse after one-character edit | median **<= 3 ms** for files <= 200 KB; **<= 10 ms** at 1 MB, in one or two slices | nvim+tree-sitter: 2-28 ms [measured, includes nvim overhead] |
| viewport highlight (60 rows) | **<= 2 ms** per query slice, resumable | query cursor on the byte range |
| memory | ~50 B per node worst case; refuse a tree (keep lexical highlighting) above a source size threshold, default **5 MB** (`treesitter_maxfile`, the option already planned in m3's TREE-SITTER.md; the owner's value) plus a long-line threshold, both options | |
| table build | background, <= 60 s worst case first time, cached | unmeasured; g2 measures |
| grammar load (JSON read + lowering) | 9 ms for cpp (437 KB), 4 ms typescript, 9 ms sql [measured] | |

### 9.2 Mechanism: a resumable state machine

`Parser.has_finished_after(budget_ns) -> StepResult { Done, Yielded }`. The parse state is
explicit (stack versions, lookahead cache, reusable-node cursor, lexer position,
progress counters); `step` runs until the budget is spent, checking the clock
every 100 operations (tree-sitter checks every 100: `OP_COUNT_PER_PARSER_TIMEOUT_CHECK
= 100` [src]) with `timer.monotonic_ns()`, and returns; the next call continues.
tree-sitter itself documents this resumption ("you can resume parsing from
where the parser left off by calling `ts_parser_parse` again" [src: api.h]).

Two ways to drive it, same engine:

1. **Cooperative (recommended first):** the editor's idle tick calls
   `pump(budget_us)` on the backend; it advances the oldest pending document.
   Deterministic and testable; no threads. The m3 loop already has a tick
   (`MED_util.Debounce`, `Tick` in docs).
2. **Worker task:** `spawn` a parse task that owns its parser, receives
   edits and sends a tree snapshot over a `Chan`. The arena design keeps the
   crossing cheap (a few big arrays, uniqueness check proportional to the
   *object* graph, which is a handful of objects). Later, if the single-thread
   slice cost proves visible.

An edit arriving while a parse is in flight **restarts** it from the old tree
plus the accumulated edits (incremental, not from scratch); the published tree
is only ever a completed or explicitly partial one.

### 9.3 Rules that keep m31 fast

- tables and trees are `Array<int>` or `bytes`, never `List<Node>`;
- the lexer loop reads from a local `str` chunk and a local table reference,
  no interface call or `Map` per byte;
- no `str` is built per token; token text is only materialised on demand (a
  query predicate comparing text uses `substr` on the chunk or a hash of the
  range);
- `wrapping_*` for hashes;
- measure with `tests/bench.m31` at every milestone, record numbers in
  `docs/PERF.md` (as `syntax` does), and treat a regression > 20% as a bug.

## 10. Integration: the `MED_ts` interface (g5)

m3's `engine/MED_ts.m31` (in `m3d1tor-wt/parity`) defines `Backend` with
`has_language`, `parse(document, language, lines)`, `edit(document, edit,
lines)`, `close`, `highlights(document, first_row, last_row)`,
`objects(document, kind, row, col)`, `folds`, `indent(document, row)`,
`injections`, `selection_chain(document, row, col)`, and `MED_ts.chain` which
asks each backend in turn. grove provides `GRV_med.Backend` implementing it:

| MED_ts call | grove |
|---|---|
| `has_language` | a grammar manifest entry exists and its tables load (or are cached) |
| `parse` | register the document, build the source adapter over the `lines`, **enqueue** the parse; returns immediately |
| `edit` | `Edit` rows/byte cols -> byte offsets via the line table; `tree.edit`; enqueue reparse |
| `highlights` | run `highlights.scm` over the byte range of the rows, return `Span`s; captures come out of the query cursor with budget; if no tree yet, return empty so the chain falls through to the lexical backend |
| `objects(kind)` | `textobjects.scm`: all captures named `kind` containing the position, innermost first |
| `folds` | `folds.scm` `@fold` captures that span more than one row |
| `indent` | `indents.scm` evaluated at the row (nvim/Helix dialects by a per-language marker) |
| `injections` | `injections.scm`: `(#set! injection.language ...)` / `@injection.language` + `@injection.content`; produces ranges to be parsed lazily as separate trees (the "included ranges" idea) |
| `selection_chain` | ancestors of the smallest named node containing the position, expanded outward, deduplicated by range |

Two small additions are needed on m3's side (QUESTIONS): a way to **drive
background work** (`tick(budget_us)` on `Backend`, or the editor calling a
grove `pump` from its loop) and a **version** number per document so the editor
can tell that highlights are stale and re-ask. Without them, `parse` on a 1 MB
file would be a stall by construction.

Highlights return nvim-style capture names; m3's `SYN_class.from_capture`
maps them to classes (the same mapping the `syntax` oracle uses).

## 11. (i) Test plan

### 11.1 The oracle

The existing approach of the `syntax` library (`docs/ORACLE.md`: nvim 0.11 plus
nvim-treesitter's compiled parsers as free, independent reference) applies
directly, one level up: instead of highlight captures, compare **trees**.

- `tests/oracle/dump_sexp.lua` (written, working): `nvim -u NONE --headless -l`
  prints the parse tree, one named node per line with field name and byte range;
  `GROVE_PARSER_DIR` points at a directory of `LANG.so` built from the same
  revision as the `grammar.json` under test (2.1 explains why this matters;
  the json case showed it).
- `tests/oracle/refresh.sh` regenerates the committed `ts/*.sexp` dumps.
- `tests/t_oracle.m31` (written) parses each fixture with grove and compares
  the dump **exactly**. 8 json fixtures pass today (with the PEG prototype),
  covering objects, arrays, numbers in six syntaxes, string escapes, nested
  containers, non-string keys.
- Per language the corpus is real files: the same listing technique as the
  `syntax` big corpus (`corpus.py`) for the report mode; ~50 committed fixtures
  of <= 120 lines for CI; no corpus content committed beyond the fixtures.
- Metrics: (1) **exact tree equality** on files the oracle parses with no
  ERROR; per language, the fraction of fixtures with equality, floor in
  `tests/oracle/floors.json` that only goes up; (2) on files with errors:
  fraction of bytes covered by identical nodes; (3) tokens: the stream of
  leaves with (symbol, start, end) compared separately from structure, to
  separate lexer bugs from parser bugs.
- Anonymous nodes (a second dump mode) and `node-types.json` consistency are
  added at g2.
- Queries: oracle on capture lists, as `syntax` does already
  (`dump_ts.lua`): for each fixture, the highlights query run by nvim and by
  grove must give the same `(range, capture)` multiset (the `syntax` repo's
  dumps are reusable).
- Scanners: for each ported scanner, a token-stream comparison against the
  oracle parser on the language's fixtures.

### 11.2 Incremental correctness

Property: for a random sequence of edits (insert/delete characters and lines,
including damaging ones), `incremental(old, edit)` equals `parse(new)`
**exactly** (all node fields), and the changed ranges cover every difference.
Run per language on its fixtures with a seeded generator; failures print the
seed and the edit script. This test needs no oracle parser, only grove against
itself, and is the strongest check on reuse conditions (4.3).

### 11.3 Fuzzing

- random byte strings and mutated fixtures (flip, delete, duplicate a line,
  truncate, insert a quote/bracket/NUL/invalid UTF-8 as U+FFFD) against every
  grammar: the invariants are *no trap, no hang (budget respected), tree
  covers the whole input, parent ranges contain child ranges, ERROR/MISSING
  accounting*; a watchdog on steps per byte;
- grammar fuzzing: truncate and mutate `grammar.json` (unknown rule type, a
  SYMBOL to nothing, a left-recursive rule with no base): the loader must
  return `Err`, never trap (the prototype's tests already check two of these);
- query fuzzing: mutate `.scm` files; the compiler returns `Err` with a line
  and column.

### 11.4 Layout and CI

Same as `syntax` and `m3`: `deps` file, `tests/test.sh` as the single entry
(`m31c -fmt --check --recursive .`, `m31c -lint .`, `tests/t_*.m31`, oracle
when nvim is present), `.github/workflows/test.yml` on Linux x86-64/aarch64
and macOS arm64 against a pinned `M31_REF` (v0.14.2), `release.yml` on `v*`
tags packaging sources, `CHANGELOG.md`, `RENAMES.md`. Oracle dumps are
committed so CI does not need nvim.

## 12. (j) Milestones

| milestone | scope | exit criteria |
|---|---|---|
| **g0** loader + lexer | `GRV_json`, `GRV_grammar` (all 16 rule types, extras, conflicts, externals, inline, supertypes, word, precedences), regex dialect to code-point NFA/DFA with `\p` tables, lexer with valid-set DFAs, pattern fixtures from the 23 grammars | all 23 grammar.json files load; every PATTERN compiles (no `R_FAIL`); the **token stream** of the json grammar over its fixtures equals tree-sitter's leaf list; load time recorded. *Partly done: JSON reader, loader, matcher over bytes, in the repo.* |
| **g1** parser, small grammars | LR(0)+LALR lookahead tables, conflict resolution by precedence, GLR stack with one/few versions, `Tree` arena, reductions with fields/aliases/hidden nodes, ERROR = stop; json, toml (no scanner; needs 2 of its 5 externals) then lua | exact oracle equality on json, lua, diff fixtures; table build time and table size recorded for json, lua, toml, css, c |
| **g2** incremental + cooperative | edit, subtree reuse, `has_finished_after(budget)`, line table, changed ranges, balancing, panic-mode recovery, anonymous-node dump, table cache | the incremental-equals-scratch property over seeded edit scripts on all g1 languages; 1-char edit and slicing numbers on a 1 MB json; fuzz suite green |
| **g3** queries | Q0, then Q1 (lua-match, offsets, locals) | captures equal nvim's on highlights fixtures for json/lua/c; textobjects/folds/indents run on Helix/nvim files |
| **g4** the first real language | c (no scanner, 8 conflicts, 1 466 states, the biggest no-scanner target) then cpp's table, then javascript with its scanner port, python, rust | c exact on >= 90% of fixtures; the table build/time budget confirmed or the cache plan upgraded; MISSING and version competition added; first numbers in `docs/PERF.md` |
| **g5** m3 integration | `GRV_med.Backend`, `pump`, document versions, highlights/objects/folds/indent/injections/selection, large-file fallback, option `treesitter_maxfile` | m3 runs with grove as the first backend for c and json; the screen tests of m3 still pass; no key-path stall measured by m3's UX-PERF harness |

Everything after g5 (the hard scanners, locals-based highlighting, more
languages) is demand-driven.

## 13. Risks and unknowns, honestly

1. **Table generation fidelity.** The generator's exact resolution (what it
   does with a shift/reduce between a `prec` and an unmarked rule, how it
   treats `conflicts` containing more than two rules, ordering of reduce
   candidates, dynamic precedence merging, `inline` of recursive rules) is
   [recalled]. The oracle will find every mismatch, but some may take time.
   Mitigation: the `parser.c` of each grammar (which we do have) lets us
   inspect the *outcome* per state: for json at g1, dump our action table and
   compare per symbol to `ts_parse_table` entries by state-isomorphism.
2. **Lexer conflict resolution** has subtle cases (precedence among tokens
   valid in a state; `word`; immediate tokens; tokens that conflict only in
   states merged by the generator). Same mitigation; the token-stream oracle
   isolates it.
3. **m31 speed.** Unknown until g1 measures. If the lexer/parser loop is 10x
   slower than tree-sitter, first parse of 1 MB is ~4 s (still sliceable), edit
   reparse ~30 ms (a visible hitch on top of the slice). The answer would be
   language-side (inlining of accessors, `const` hoisting: both on the perf
   board) and not in grove.
4. **Scanner ports** (6.2): 5 large ones; markdown and yaml are the hard
   cases the owner may not want at all.
5. **Unicode tables** (`\p{..}`): need generating from Unicode data; the
   generator is a script in `scripts/`, the tables committed. Licence of the
   data (Unicode License) needs a line in `THIRD_PARTY_NOTICES`.
6. **Query dialect drift** between nvim and Helix (7.2). Needs the owner's
   policy (QUESTIONS).
7. **Licences.** The grammar repositories and query files carry their own
   licences. Only tree-sitter-json's LICENSE (MIT) was read here and it is
   vendored beside its grammar.json in `tests/data/json/`. nvim-treesitter
   queries: Apache-2.0 per `m3d1tor-wt/parity/docs/TREE-SITTER.md` (checked
   there); Helix queries: MPL-2.0 [recalled there as "to verify"]. A manifest
   check must fail on anything not permissive before any grammar is vendored.
8. **Memory.** Per-language tables of 1-20 MB plus ~50 B per node; the owner
   sets the budget.

## 14. g1 results (version 0.1.0)

g1 is built: grammar.json to productions (`GRV_lang`), LR tables with GLR forks
(`GRV_lr`), a lexer of lazily built DFAs (`GRV_lexer`, `GRV_regex`), the parser
(`GRV_glr`) and a tree with the oracle's dump (`GRV_tree`). Everything below was
measured on this machine with the public m31 v0.14.2, `cc -O2`, one core; the
commands are in `tests/tables.m31` and `tests/bench.m31`, the recorded output in
`experiments/results/`.

### 14.1 What matches the oracle

- json: the 8 fixtures are identical to tree-sitter's trees (types, fields, byte
  ranges), now with the LR/GLR parser as well as with the PEG prototype.
- c: the 6 small fixtures and 22 microtests of the tricky places (preprocessor
  lines, escapes, `a = b = c`, a blank line after `#include`) are identical.
- c, real files: of 90 sampled sources and headers (`/usr/include`, the kernel
  tools tree) tree-sitter parses 21 without ERROR; grove's tree is identical on
  **9 of those 21**. The 12 others are listed in
  `experiments/results/c_many_files.txt` (section 15.3 has the current numbers). They are not random bugs: 9 are a
  parse failure on a construct whose GLR resolution differs from tree-sitter's
  (`__BEGIN_DECLS` followed by `typedef`, `goto done;` before `case`, a call
  statement after declarations, `__extension__`, a lone `}` inside `#ifdef`), 1 is
  a lexical-precedence case (`#define X /* c */`: tree-sitter lexes the comment,
  grove the macro argument), 1 a node-type choice at a conflict (`macro_type_specifier`
  against `expression_statement`), 1 an end of range. They are g4 work.

### 14.2 Measured: table build

`tests/tables.m31`, load = read grammar.json, flatten = productions, tables =
LR(1) states with safe merging, conflict resolution and entries:

| grammar | symbols | productions | states | table entries (KB as int arrays) | forks | load + flatten | tables |
|---|--:|--:|--:|--:|--:|--:|--:|
| json | 27 | 27 | 42 | 178 (1) | 0 | < 1 ms | < 1 ms |
| lua | 141 | 195 | 314 | 8 273 (64) | 4 | 2 ms | 45 ms |
| c | 268 | 1 371 | 1 961 | 98 643 (770) | 33 | 13 ms | 463 ms |
| go | 212 | 511 | 868 | 24 048 (187) | 62 | 5 ms | 145 ms |
| java | 295 | 1 056 | 1 974 | 58 354 (455) | 52 | 9 ms | 450 ms |
| javascript | 262 | 1 511 | 2 429 | 105 336 (822) | 1 036 | 12 ms | 462 ms |
| python | 273 | 854 | 1 500 | 51 466 (402) | 957 | 6 ms | 328 ms |
| rust | 344 | 4 178 | 6 033 | 218 930 (1 710) | 2 146 | 23 ms | 1 739 ms |
| typescript | 388 | 4 385 | 8 271 | 347 208 (2 712) | 3 800 | 33 ms | 2 533 ms |
| cpp | 564 | 2 288 | 3 813 | 215 330 (1 682) | 2 038 | 18 ms | 1 703 ms |
| sql | 726 | 6 960 | 15 380 | 210 000 (1 640) | 5 | 124 ms | 3 757 ms |
| kotlin | 366 | 1 826 | 2 983 | 240 065 (1 875) | 7 451 | 20 ms | 1 148 ms |
| bash | 294 | 5 064 | 7 716 | 203 000 (1 585) | 3 631 | 31 ms | 2 809 ms |
| yaml | 298 | 693 | 909 | 15 714 (122) | 316 | 4 ms | 53 ms |

Conclusions that settle questions of sections 3.4 to 3.7:

1. **A table generator in m31 is cheap enough to run at load time**: json, lua
   and c in well under half a second, the largest grammar (sql) in 3.8 s, the
   hardest to resolve (typescript) in 2.5 s. This is without any optimisation. The
   disk cache of 3.7 is therefore an optimisation for the first open of a big
   language, not a precondition (as the owner decided).
2. **Memory is small**: the tables are 0.1 to 2.7 MB as `Array<int>` (8 bytes per
   entry); the biggest is typescript. My estimates of 3.6 (up to 20 MB) were an
   order of magnitude high, because the generator does not build tree-sitter's
   dense large-state rows.
3. **The LR(0)-core experiment was a good predictor of size** (c 1 128 LR(0)
   states, 1 961 here; tree-sitter 1 466) and a bad one of fidelity: the real
   problem was not state count but merging (14.4).

### 14.3 Measured: parse speed

`tests/bench.m31`, the GLR parser with its lexer, steady state:

| input | bytes | tree nodes | cold lexer | warm lexer | tree-sitter (nvim, 3.2) |
|---|--:|--:|--:|--:|--:|
| json, generated | 1 727 103 | 1 359 002 | 1 080 ms | 1 067 ms | 341 ms |
| json | 113 215 | 90 602 | 69 ms | 68 ms | |
| c (a clean fixture repeated) | 608 000 | 402 001 | 385 ms | 391 ms | |

That is 1.6 MB/s in m31 against 3 to 5 MB/s for tree-sitter: **2 to 3 times
slower**, not the 10 times feared in 9.1. The lexer builds 49 DFA states for the
whole JSON file and 279 for the C one, so lazy construction is cheap. This parse
has no node reuse and allocates a tree node per token and per reduction; g2 (flat
immutable tree, no per-reduction lists) should recover part of the gap. The PEG
prototype takes 281 ms for the 113 KB JSON file, 4 times slower than the GLR parser.

### 14.4 Where the implementation differs from the design (and why)

1. **LALR was not enough; the tables are LR(1) with merging only when safe.** (Section 16
   corrects this: the merging rule described here still failed on `a = b = c`, which g1 claimed to
   parse; it did not. What is built now is described there.)
   LALR merged the state after an identifier on the right of `=` in C with a
   state where `_expression -> identifier .` can be followed by `=`; the spurious
   shift/reduce conflict was resolved by precedence in favour of the reduce, and
   `a = b = c`, `a.b = c`, `*a = b` failed to parse. The fix is Pager's idea,
   tested directly: a new state with an existing core is merged into it only if
   the merged state has no conflict (reduce/reduce or reduce/shift) that either
   did not have. The change cost 23 states in C (1 938 to 1 961).
2. **The repeat rule `aux -> aux aux` is ambiguous by construction**; a tie
   between reducing it and shifting is resolved as reduce, so the stack stays
   shallow (checked on json: 0 forks).
3. **Extras that are non-terminals** (lua's multi-token comment) are added to every
   state's closure with every terminal as lookahead and a goto to the same state.
   Built and measured (lua tables), not yet parsed (lua needs its scanner).
4. **Lexing rules inferred from the oracle** (not from the generator): the
   longest match wins unless it has lower precedence; a character that is both
   whitespace and the start of a token is part of the match (tree-sitter's trees
   show C's `"\n"` taking blank lines after `#include`), a restart after such a
   character is allowed only through characters that are again both, never through
   a pure skip or a comment, and not when the state already accepts a token of
   precedence above 0 (a space after an escape inside a C string stays content).
   These rules reproduce eight small cases and nine real files; the generator's
   real rule is still unknown (`GRV_lexer`'s header says so).
5. **Unicode properties are approximations** (`GRV_regex.add_property`): ASCII
   exact, common blocks for letters, digits and spaces. The real tables are still a
   g0 task.
6. **Forks are counted, not checked against `conflicts`.** The `forks` column is
   how many (state, lookahead) pairs keep several actions; tree-sitter would
   refuse any not declared. C has 33 against 8 declared conflict groups; for
   javascript (1 036), python (957), kotlin (7 451) and typescript (3 800) the
   count shows that conflict resolution differs from the generator's more than
   it should. Those grammars cannot be trusted until forks fall to the declared
   conflicts. It is the first thing to examine in g4.
7. The tree is still g1's: absolute offsets, a node per token. Section 5 stays
   the design for g2.

### 14.5 What g1 does not do

Error recovery (a failure leaves `root = -1` and `error_at`), external scanners,
incremental reuse, queries, anonymous nodes in the dump, `MISSING`, dynamic
precedence beyond picking the highest sum among finished versions, version merging
beyond equal (state, parent), named-precedence ordering across lists.

## 15. g2 results (version 0.2.0)

g2 is built: the tree of section 5 (relative padding and size, immutable nodes,
versions that share subtrees), the edit of section 4.2, reuse with tree-sitter's
conditions, resumable parsing, a first error recovery and the many-file oracle. All
numbers were measured on this machine, m31 v0.14.2, `cc -O2`, one core
(`tests/bench.m31`, `experiments/results/g2_bench.txt`).

### 15.1 The tree and the edit

- `GRV_tree`: `padding`, `size`, `lookahead`, `production`, `flags`, children in one flat
  list, `repeat_depth` for repeat nodes. A node is an int; there is no parent link;
  absolute positions are sums along the path. `full()` dumps every node (symbol
  ids, byte ranges, the extra mark, repeat nodes flattened); two trees of the same text
  are the same exactly when `full()` is equal.
- **Repeats are kept shallow.** A list read as `aux -> aux aux` is left-leaning: 1 600
  items made a tree 800 deep, and an edit copied 429 nodes. The parser now appends an
  item to the right subtree while it is shallower than the left one (a binary counter),
  so the depth is 10 for 200 items, 12 for 400, 13 for 800, 15 for 1 600, and an edit
  copies 24 to 29 nodes. (tree-sitter does a similar rebalancing after the fact.)
- `GRV_edit.apply(tree, start, old_end, new_end)` copies the path to the edit and
  marks it changed; a node is touched when the range meets its padding or body or the
  window its shape depended on (`lookahead`: what its last token's lexer looked at and
  the token the parser had read when it reduced it). The new root shares everything
  else; the old root is still a valid tree. `compact()` copies what is reachable
  into a fresh tree (1.41M nodes to 1.36M after ten edits on the 1.7 MB JSON file,
  in 0.3 s).

### 15.2 Reuse, slicing, recovery

- **Reuse** (`GRV_glr.Parser`): with one version, a node of the old tree that starts
  at the parser's position is pushed whole if it is unchanged, not fragile (built
  while there were several versions or from a state with several actions), has no
  ERROR, the table's action on its first token is one SHIFT (then it needs a goto
  for the node's symbol) or one REDUCE (the reduction is done first, as a lexed token
  would ask, and the node is looked at again), and the lexer, run in the current
  state, gives that first token again. The reduce-first rule matters: without it the
  parser fell back to single items after the first reused chunk of a list (18 000
  tokens lexed per edit); with it 63.
- **Slicing**: `Parser.has_finished_after(budget_ns)` runs rounds until the time is spent
  (the clock is read every 8 rounds) and returns whether the tree is complete; the next
  call continues. `has_finished_after(0)` stops after 8 rounds, which is what the
  tests use (no clock involved).
- **Errors**: when every version is stuck the parser looks at most 16 entries down for
  a state that accepts the token, wraps what lies above it in an ERROR node (an extra,
  so the stack stays valid), otherwise wraps the token and goes on; at the end of
  input everything is one ERROR. The tree always has a root. The nodes above an ERROR
  are marked and never reused. No MISSING tokens and no version cost comparison yet
  (SPEC 8.2 steps 3 and 4).

### 15.3 Measured

| | 1.7 MB JSON (1.4M nodes) | 608 KB C (410k nodes) |
|---|--:|--:|
| parse from scratch | 0.9 to 1.0 s | 0.30 to 0.34 s |
| `apply` of one edit (mid-file) | 18 to 23 us | 14 to 18 us |
| reparse after one inserted space, mid-file | **72 to 90 us**, 63 tokens lexed, 18 nodes reused | **64 to 84 us**, 48 tokens, 18 nodes |
| nodes copied per edit | 32 | 27 |
| worst reparse of 10 | 124 us | 153 us |
| tree-sitter, same kind of edit (nvim, SPEC 3.2) | 15.6 ms | 22.7 ms |

An edit that leaves the syntax alone costs about 0.1 ms whatever the file size, and it
needs no slicing. An edit that changes the lexical context of the rest of the file
(an opened string or block comment) still re-reads until the context closes: the
hostile edits of `tests/t_incr.m31` do that, and the result equals a scratch parse.

The many-file oracle (`tests/oracle/report.sh`, nothing committed but the reports):

| language | files compared | identical | different | skipped (tree-sitter reports errors) |
|---|--:|--:|--:|--:|
| json | 1 000 (<= 300 KB) | **990** | 0 | 10 |
| c | 400 (<= 60 KB) | 136 | 66 | 198 |

All 990 clean JSON files are node-for-node identical, ranges and fields included. The
66 C differences are the fidelity gap of section 14.4 item 6 (mostly "the tree has
errors": a construct on which grove's GLR resolution differs from tree-sitter's).

### 15.4 Tests (all independent of the clock)

`t_incr`: for json and c, 80 hostile random edits and 60 benign ones each, a
fixed-seed generator: the incremental tree must equal the scratch tree
(`full()` and the error flag), nodes must be reused, and benign edits must read
under a third of the tokens of scratch parses (a ratio of counts). `t_recover`:
slicing with a zero budget gives the same tree as one go; recovery keeps what
surrounds an error; 150 random texts per grammar always finish with a root that
covers the input. `compact` keeps the tree.

## 16. Conflict resolution: what tree-sitter really does (version 0.3.0)

The g1 table builder kept far more forks than "the declared conflicts" suggested (c: 33
against 8 groups; javascript 1 036; python 957; typescript 3 800; kotlin 7 451), and some
C files failed to parse. g2's hand-back promised to find out why. The question was
framed wrongly, and the answer is in tree-sitter's own tables and runtime.

### 16.1 Method

- `experiments/ts_forks.py` decodes `ts_parse_actions`, `ts_parse_table` and
  `ts_small_parse_table` of a grammar's `parser.c` and lists the (state, lookahead) pairs whose
  action entry holds several actions. `experiments/ts_fork_classes.py` groups them by class (the
  sorted actions: `S` shift, `R:rule:length` reduce, repeat rules as `AUX`).
- `tests/forks.m31` prints the same classes for grove's tables, and
  `experiments/compare_forks.sh` compares the two per grammar. A class is the unit of
  comparison, not the count: tree-sitter merges states (c has 1 466, grove's first tables had
  1 961 before and 3 440 now), so one conflict is held by a different number of states in
  each.
- The runtime rules were read in `tree-sitter-0.24.7/src/parser.c`
  (`ts_parser__select_tree`) and `subtree.c` (`ts_subtree_compare`).

### 16.2 What was found

1. **"Declared conflicts" is not a count of forks.** tree-sitter's own `parser.c` holds
   162 fork pairs for C (34 outside repeats), 171 for JavaScript (131 outside repeats),
   1 547 for Python (1 386), 1 124 for TypeScript (1 063), 1 721 for Kotlin (1 550), 221 for
   Java, 102 for Go, 4 for JSON. A `conflicts` group is a set of rules that may be ambiguous;
   the same group appears in many (state, lookahead) pairs. The right measure is which
   classes of fork exist, and whether the same ones do in both.
2. **tree-sitter does not resolve a repeat's `aux -> aux aux` tie.** Its tables keep
   `REDUCE(aux_repeat) + SHIFT_REPEAT` as a fork (128 of C's 162, all 4 of JSON's). grove
   resolves the tie to the reduce (a shallow stack); the trees differ only in hidden repeat
   nodes. A dedicated `SHIFT_REPEAT` exists so the runtime can still treat the two versions as
   one.
3. **Which version survives is decided by tree-sitter's runtime, by three rules**, in order
   (`ts_parser__select_tree`): fewer errors; higher dynamic precedence (a subtree's is the sum
   over its children and its own production); otherwise `ts_subtree_compare`: the tree whose
   first differing node has the **lower symbol id**, or, at equal symbols, **fewer children**,
   walking children in order. grove used only the dynamic precedence and kept the first on a
   tie, which chose `sizeof ( type_descriptor )` over `sizeof parenthesized_expression`
   where tree-sitter picks the expression (fewer children). Implemented in
   `Parser.should_replace`; symbol ids follow the same order as tree-sitter's (terminals by
   first appearance, then rules, then repeat rules).
4. **Three static-resolution rules were wrong and are corrected**, each found by a class of fork
   that tree-sitter does not have:
   - *Associativity with precedence 0.* `prec.right(0, ...)` (C's `if_statement`, resolving the
     dangling else) carries an associativity but no precedence; applying a reference's
     metadata to an inlined rule's steps only when `prec != 0` lost it. The 14 `R:if_statement |
     S` forks of C vanished.
   - *Named precedences compare above integers.* A name (`'call'`, `'binary_plus'`) against an
     unmarked or integer precedence resolves in the name's favour (JavaScript's `arrow_function`
     against `+`, `.`, `(`); two names compare by their position in a `precedences` list, and
     names of different lists are equal.
   - *A shift takes the precedence of the kernel items that lead to it.* In `x => y (`, the shift of
     `(` belongs to `arguments`, whose own steps have no precedence; the precedence is on the
     `call_expression` item that has `arguments` after its dot. A kernel item gives its step
     precedence to every terminal that can start the symbol after its dot.
5. **Plain LALR was not just imprecise, it was wrong, and the g1 fix did not fully work.**
   g1 claimed `a = b = c` parsed; with the micro tests it did not (they did not contain it). The
   cause is in the numbers above: a reduce/shift conflict resolved by precedence is correct only
   in the contexts where the reduce lookahead is real, and merging contexts adds spurious
   lookaheads. Pager-style merging (g1) tests conflicts of the state being merged but not the
   conflicts it creates downstream. What works: **canonical LR(1) identity for the terminals on
   which any state conflicts, LALR for the rest**. The first pass builds LALR and collects
   every terminal with a reduce/reduce or reduce/shift conflict (repeat rules excluded: their
   tie is always settled the same way); the second pass keeps apart states whose lookaheads
   differ on those terminals and merges the others by union. Because only a conflict makes a
   lookahead matter, this is exact where it counts. A final pass merges states of equal core with
   compatible rows (equal actions where both have one, to the same classes), which is what brings
   canonical LR(1) back near tree-sitter's size (C: 7 301 states to 3 440; tree-sitter 1 466).

### 16.3 Measured

`experiments/compare_forks.sh` (non-repeat forks; classes are shared when "only in" is 0):

| grammar | tree-sitter forks (of which repeat) | non-repeat, tree-sitter | non-repeat, grove | classes only in grove | classes only in tree-sitter |
|---|--:|--:|--:|--:|--:|
| json | 4 (4) | 0 | 0 | 0 | 0 |
| c | 162 (128) | 34 in 7 classes | 24 in 7 | **0** | **0** |
| go | 102 (38) | 64 in 6 | 54 in 5 | 0 | 1 (1 fork) |
| java | 221 (163) | 58 in 5 | 84 in 6 | 1 (5 forks) | 0 |
| python | 1 547 (161) | 1 386 in 6 | 631 in 7 | 1 (2 forks) | 0 |
| javascript | 171 (40) | 131 in 14 | 692 in 16 | 5 (396 forks) | 3 (22 forks) |
| typescript | 1 124 (61) | 1 063 in 47 | 1 114 in 52 | 19 (190 forks) | 14 (387 forks) |
| kotlin | 1 721 (171) | 1 550 in 19 | 1 299 in 20 | 4 (178 forks) | 3 (27 forks) |

The earlier "c 33 against 8 groups" is therefore **24 against 34** with the same 7 classes; the
"javascript 1 036, python 957, typescript 3 800, kotlin 7 451" are now 692, 631, 1 114 and 1 299,
against 131, 1 386, 1 063 and 1 550 in tree-sitter. (javascript is the one that is still 5 times
too high; see 16.4.)

Table builds (`tests/tables.m31`, m31 v0.14.2, `cc -O2`, one core; the new method has a state
limit of 16 times the LALR count, at most 60 000 (counted before the final merge), beyond which the LALR automaton is kept and the
table says so):

| grammar | states | table entries (KB as int arrays) | build | resolved how |
|---|--:|--:|--:|---|
| json | 42 | 178 (1) | < 1 ms | exact |
| lua | 441 | 11 713 (91) | 136 ms | exact |
| c | 3 440 | 153 525 (1 199) | 2.8 s | exact |
| go | 2 435 | 83 824 (654) | 1.5 s | exact |
| java | 3 521 | 135 453 (1 058) | 2.5 s | exact |
| javascript | 5 315 | 265 089 (2 071) | 4.6 s | exact |
| python | 3 966 | 132 370 (1 034) | 2.3 s | exact |
| yaml | 889 | 14 971 (116) | 0.2 s | exact |
| typescript | 7 933 | 327 062 (2 555) | 21 s | LALR (limit) |
| cpp | 3 649 | 204 132 (1 594) | 13.5 s | LALR (limit) |
| rust | 5 725 | 204 947 (1 601) | 10.5 s | LALR (limit) |
| kotlin | 2 354 | 202 404 (1 581) | 3.5 s | LALR (limit) |
| sql | 15 073 | 197 195 (1 540) | 12.9 s | LALR (limit) |
| bash | 7 406 | 184 043 (1 437) | 23.6 s | LALR (limit) |

"exact" means the second pass fit under the limit; before the limit existed it took, to finish,
rust 18.5 s and 59 519 states, typescript 36 s and 16 816 states, cpp 62.5 s and 28 275, bash 51 s and
23 161, and sql more than 190 s. **For the big grammars the disk cache is no longer an
optimisation**: even the fallback takes 10 to 24 s, and the exact tables would take a minute.

C against tree-sitter on real files (`experiments/results/c_many_files.txt`): 400 sources and
headers from `/usr/include` and the kernel tools tree; **143 are comparable** (tree-sitter
reports no ERROR and no MISSING; the dump now prints anonymous MISSING nodes, which hid 66
"differences" that were tree-sitter's own error recovery); **140 are identical, 3 differ** (98%).
JSON stays at 990 of 990.

### 16.4 What is still different

- (0.6.0: the arrow_function classes are explained, see section 19.2; the 3 C files are explained and
  fixed, see 19.1.) The classes that remain for Kotlin and TypeScript are listed in 19.2.
- The LR(1) splitting multiplies states on grammars with many conflict terminals (rust:
  59 519 states; tree-sitter 3 649). The limit above falls back to LALR; the better fix is
  a smaller mask (terminals whose conflicts are resolved by precedence, not those that stay
  forks).

## 17. External scanners and Lua (version 0.4.0)

### 17.1 The interface

`GRV_scan` defines what section 6.3 sketched: `Scanner` (an interface of three methods: `scan`,
`save`, `restore`) and `ScanLexer` (a concrete type, tree-sitter's `TSLexer`: `lookahead`, `advance`,
`mark_end`, `is_at_end`; the token ends at the last mark, characters passed with `advance(true)` are
padding). `scan(lexer, valid)` gets the external tokens valid in the parse state as a `List<bool>` in the
order of the grammar's `externals`, and returns the index of the token it produced or -1.
`GRV_scanners.for_language(name)` returns the scanner for a grammar name. The lexer calls it before its
own automaton whenever the parse state accepts at least one external token (as tree-sitter does); on -1
it lexes from where it started.

The scanner's state is `save()`d after every external token and kept with the stack entry it belongs to
(`Stack.scan` indexes a list of byte strings), and `restore()`d before every scan on that stack, so
forks and the reuse of old subtrees see the state that belonged to their position.

### 17.2 What incremental reuse does with scanner state

A node is reusable only if the scanner was at rest (its initial state) when the node started, which the
parser checks, and the node does not end with the scanner open. Two tree flags record that:
`HAS_EXTERNAL` (an external token somewhere inside) and `ENDS_OPEN` (the scanner state after the last
external token inside is not at rest: a block comment or string that is not closed in the node). Only
`ENDS_OPEN` prevents reuse: a function containing a closed long string is reused whole; one that opens a
bracket and closes it in a later sibling is not. Measured on a 295 KB Lua file (functions with long strings
and block comments): reparse after one inserted space 141 to 169 us, 50 tokens lexed, 13 nodes reused.

### 17.3 The Lua scanner

`GRV_scan_lua` is a hand translation of tree-sitter-lua's 194-line `scanner.c`: long brackets
`[==[ ... ]==]` close only on the same number of `=`, in strings and in `--[==[` comments; the state is that
number (and an ending character that is always 0 in this grammar). 22 checks drive it directly
(`tests/t_scan.m31`): what it accepts, where the token starts and ends, the saved state. The lua
`comment` rule is a non-terminal extra (a `--` token and a content token, or the three external ones);
the table builder's extra-rule support (SPEC 14.4 item 3) was written for it and works.

### 17.4 Measured against tree-sitter

- The 7 Lua fixtures (hello, strings, comments, control flow, functions, tables, operators) and, over
  400 real Lua files from the nvim runtime (<= 60 KB; `experiments/results/lua_many_files.txt`):
  **399 identical, 1 different**; the one is a file that is not valid UTF-8 and so cannot be an m31 string.
- 6 other changes were needed to get there, each found by a failing Lua case:
  1. a rule that is just a token (`empty_statement: ';'`) and the same token written inline (the `;`
     between the fields of a table) are two terminals; sharing them printed an `empty_statement` node
     inside tables (0.5.0 refines this, see 18.6);
  2. a token that matches the empty string (`/[^\r\n]*/` after `--`) is a token of no width when nothing
     else matches (an empty comment `--` before the newline);
  3. fragility spreads upward as in tree-sitter: a node whose first or last child is fragile or an ERROR is
     fragile;
  4. a node reduced for a lookahead that then turns out to have no action in the new state (merged states
     accept some invalid lookaheads and find out a step later) is fragile, and so is every node reduced on
     a stack above an ERROR;
  5. nodes reduced while the stack held an ERROR (also one re-pushed after a reduction) are fragile;
  6. the incremental test now includes Lua and its hostile edits (`[[`, `]]`, `--`, `--[[`, `]==]`).

### 17.5 What this does not do yet

Scanner state is not part of a node's identity beyond the two flags above; a scanner whose state matters
inside every node (Python's indent stack) will need the state kept per node, as tree-sitter does; the other
16 scanners (SPEC 6.2) are untouched.

## 18. Queries, subset Q0 (version 0.5.0)

### 18.1 What is supported

`GRV_query.parse(source)` reads a tree-sitter query file and `GRV_query.run(query, tree, text, from, to)`
returns the captures of every match whose nodes meet the byte range, sorted by start, longer first, then
pattern number, without duplicates. Supported syntax:

- node patterns `(type ...)`, anonymous tokens `"text"`, wildcards `(_)` (named) and `_` (any), `(ERROR)`;
- fields `field: pattern` and negated fields `!field`;
- captures `@name` (several per node), alternations `[ ... ]`, groups of siblings `( (a) (b) )` (a plain
  group is spliced into the parent's children; a quantified or captured group of several nodes is not
  supported), quantifiers `? * +`, anchors `.` (first child, last child, immediate sibling; anonymous
  nodes are skipped);
- predicates `#eq?` `#not-eq?` `#any-eq?` `#match?` `#not-match?` `#lua-match?` `#not-lua-match?`
  `#any-of?` `#not-any-of?` `#has-ancestor?` `#has-parent?` and their `not-` forms (against a capture or a
  string, as the arguments say); an unknown predicate is true;
- directives `#set!` (kept per pattern in `Query.properties`) and `#offset!` (the four deltas are
  reported on each `Found`; the caller applies them as nvim does).

Not supported: quantified or captured multi-node groups, `#is?`/`#is-not?`, `(MISSING ...)` (not tested), supertype
subtyping (`(expression/identifier)`), predicates written with a different arity than nvim's, and
`; inherits` / `; extends` (the caller concatenates files).

### 18.2 The visible tree

A query sees the tree-sitter tree, not the parse tree: a hidden node (a name starting with `_`, repeat
helpers, inlined rules) is replaced by its children; an alias renames a node and makes it named or
anonymous; the field of a hidden node's child is the field its parent gave the hidden node. Anonymous
visible tokens match `"text"`. This is why the tree oracle (section 14) and the query oracle agree.

### 18.3 Regexes and Lua patterns

`#match?` compiles its regex with `GRV_regex` (the lexer's engine, so Unicode classes are the
approximations of 14.4); `GRV_find` adds the leading `^` and trailing `$`. `#lua-match?` translates the
Lua pattern to the same engine: `%a %d %l %s %u %w %x %p %c` and capitals, sets, `.`, `* + - ?` after an
item, anchors, groups. `%b` and `%f` are not translated and the predicate is false. nvim and Helix differ:
nvim-treesitter writes `#lua-match?` and `#has-ancestor?`, Helix writes `#match?` with a different regex
dialect; both are in the subset, a Helix file is not checked here.

### 18.4 Against nvim

The highlights of nvim-treesitter (cf12346, Apache-2.0, `tests/data/queries`; c.scm pruned of the
patterns naming node types the grammar revision of the repository does not have) run in nvim 0.11.5 with the
compiled parsers of the same revision and in grove, over the same bytes; the comparison is of sets of
`name start end` (rows and columns, `#offset!` applied):

- fixtures (committed, `tests/t_query_oracle.m31`): 45 files, json 8, c 30, lua 7, all identical;
- real files (`tests/oracle/report_captures.sh`, `experiments/results/query_many_files.txt`): json 284 of
  284 comparable identical; lua 299 of 299; c 93 identical, 3 different (204 skipped: nvim cannot query
  them or grove's tree has errors).

The three C differences are tree differences, not query ones: grove makes `free(p);` a declaration with
`free` a type and `long mt_dsreg;` a sized type with a type_identifier, where tree-sitter picks the call
and the declarator. They are the kind of difference the tree oracle also shows for C (3 of 143 files, section 14; not
checked whether they are the same files): a choice between forks that grove's tables do not yet make the
same way as tree-sitter's.

### 18.5 Speed, not optimized

Measured (m31 -O2, one core, 0.5.0): C highlights on a 280 KB header: parse 34 ms, a full query run 151 ms
(7 824 captures), a 4 000-byte window 1.2 ms; Lua 53 KB: parse 37 ms, query 158 ms (11 801 captures), a
4 000-byte window 14 ms; JSON 184 KB: parse 63 ms, query 181 ms, window 4 ms. A query is slower than the
parse and the window is not yet proportional to its size; it must be below a frame (g4 budget, section 9)
before the editor calls it on the key path, so the editor runs it on the visible range after a reparse
and the next step is a per-node index of the patterns that can match (the by-type index is only the
start of that).

### 18.6 The terminal of a rule that is only a string

tree-sitter's trees show that a rule such as Lua's `empty_statement: ';'` is a node with one anonymous
child `;`, while json's `true: 'true'` is a node with no children. The difference is whether the same
string is also written inline in some rule: then there is one anonymous terminal and the rule is a
non-terminal around it; otherwise the rule itself is the terminal. 0.4.0 made them two terminals, which
fixed the table fixture but dropped the child, and the query oracle found it (10 of 299 Lua files missed
`punctuation.delimiter` on a statement `;`). `GRV_lang.build` now notes every token written inline before
it assigns terminals.

## 19. Conflict resolution, second round, and the table cache (version 0.6.0)

### 19.1 Versions that never met (the three C files, and more)

The three C files of section 16 were not a precedence problem. Two readings of the same text, for
instance `free(p);` as a call or as a `macro_type_specifier` followed by `;` (dynamic precedence -1), or
`sizeof(z)` as an expression or as a type, were kept as separate versions of the parser, because versions
merged only when the stack entry under their top was the very same entry. A second statement made the
two readings of the first one into four versions, and with three `free(p);` in a row the 16-version cap
dropped the better reading. 0.6.0 changes three things:

- two versions at the same position merge when their stacks have the same shape: the same states from
  the bottom, errors in the same entries (two polynomial hashes kept per stack entry) and the same scanner
  state. This is the effect of tree-sitter's graph-structured stack, which links such stacks into one;
- which of two merged versions survives is decided on the entries just above the shared part of the two
  stacks (the alternative readings), with the dynamic precedence and then `ts_subtree_compare` as in
  `ts_parser__select_tree`; and a reduction that lands in the shape of a version already waiting in the
  same round is compared when it is made, which is where tree-sitter calls `select_children`. Without that,
  `sizeof(z)` was decided by comparing the next token;
- a text that is only blank has an empty root padded by the blank (tree-sitter: `1-1`, not `0-1`).

Measured on 300 C files (`report.sh`, 109 comparable): **before 92 identical, 17 different; after 109 and
0**. Query captures on the same files 109 of 109 identical (were 93 + 3 in 0.5.0). Lua 399/400 and json
284/284 as before.

### 19.2 A rule listed in `precedences` is a named precedence

The JavaScript fork class `arrow_function:3 | S` (196 forks, with `:4`) came from this: the first list of
`precedences` in tree-sitter-javascript ends with `$.update_expression ... $.sequence_expression,
$.arrow_function`, rule names, not strings. tree-sitter lets a rule name stand in a list, and the
productions of that rule then compete under that name. Grove now gives the items of a listed rule the
named precedence of the rule (unless they carry an explicit named one) **in shift/reduce conflicts**. In
reduce/reduce conflicts it must not: trying it removed forks tree-sitter keeps (`pattern | primary_expression`).
The rest is by experiment against parser.c (`experiments/compare_forks.sh`; forks, with classes only on
one side):

| grammar | tree-sitter forks (non-repeat) | grove before | grove now | only in grove / only in tree-sitter |
|---|--:|--:|--:|---|
| javascript | 131 | 692 | 283 | 3 classes (5 forks) / 3 classes (22 forks) |
| python | 1 386 | 606 | 631 | 1 class (2) / 0 |
| c | 34 | 24 | 24 | none / none |
| go | 64 | 54 | 54 | none / 1 repeat class (1) |

What still differs in JavaScript: tree-sitter keeps 17 `pattern | shift`, 3 `assignment_expression |
object_assignment_pattern` and 2 `_initializer | shift` forks (declared conflicts) that grove resolves, and
grove keeps 3 `expression | shift`. A no-precedence versus integer-0 ordering (none < 0, from the order of
the Rust enum) was tried and removed: it fixed the arrow classes by accident and broke the reduce/reduce
cases. TypeScript, Kotlin and the other LALR-fallback grammars still show their old extra classes; they
are compared against LALR tables, which have spurious forks of their own.

### 19.3 The narrower conflict mask: tried, not kept

Restricting the LR(1) split to terminals whose conflicting states carry a precedence, an associativity or a
listed rule (only those can be resolved wrongly by LALR) did make rust and bash exact within the limit, but
at 59 566 and 13 223 states against tree-sitter's few thousand, 11.5 and 2.9 MB of table and no gain on
typescript, cpp, kotlin or sql, which still overflow. It was removed. The cause is that identity is by
masked lookahead sets, so states split once per distinct subset; the useful fix is Pager's weak
compatibility during construction, merging a new state into an old one of the same core whenever no
conflict can appear, instead of splitting first and merging after. That is not done; the six big grammars
stay on LALR (flag `is_lalr`), and the cache below makes that a one-time cost.

### 19.4 The table cache (`GRV_cache`)

`GRV_cache.build_cached(lang, grammar_text, directory)` returns the tables from a file named
`grove-VERSION-HASH.tbl` when there is a valid one and otherwise builds and writes them. HASH is two
polynomial hashes and the length of the grammar.json text; VERSION is `GROVE_VERSION` (a test compares it
with `deps`). The file is text (one line of numbers per array) with a header that repeats version and
hash, the counts of terminals and productions, and a checksum over every number; any mismatch, truncation
or damage is a miss, never an error, and the table is rebuilt and the file replaced. A file is written to
`NAME.tmpNANOSECONDS` and renamed (`fs.rename`), so a reader sees a whole file or none. The directory is
`$GROVE_CACHE_DIR`, else `$XDG_CACHE_HOME/grove`, else `$HOME/.cache/grove`; an unusable directory means no
cache, not a failure. Measured (m31 -O2): javascript 4 165 ms to build, 91 to 95 ms to read (2.0 MB);
bash 29 440 ms (the LALR fallback, with the failed attempt) and 63 ms (2.9 MB). The fork log is not cached
(diagnostics only). Not done: a size limit or cleaning of old versions' files; a binary format.
