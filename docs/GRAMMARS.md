# The 23 target grammars

Survey of the languages in the owner's first set (c, cpp, rust, go, python,
javascript, typescript, tsx, java, kotlin, lua, bash, json, yaml, toml, html,
css, markdown, markdown_inline, sql, dockerfile, make, diff).

Source of the numbers: the `grammar.json`, `parser.c` and `scanner.c`/`scanner.cc`
of every language, from the grammar checkouts under
`/home/nox/homelab/apps/nox/runtime/grammars/sources/` (all 23 are there; the
typescript/tsx/markdown/markdown_inline sources live in subdirectories of
their repositories), by `experiments/grammar_survey.py`
(`experiments/results/grammar_survey.txt`). **These checkouts are not the
revisions pinned by nvim-treesitter's `lockfile.json`** (they are the revisions
somebody else vendored; e.g. their json differs from nvim's, SPEC 2.1), so
counts will move with the revision chosen. Pinning one tuple of
(grammar.json, queries, oracle parser) per language is the first task of g0.

## Size and shape

"rules" = entries of `rules`; "rule nodes" = every node of every rule tree
(the work the loader does; grove loads cpp's 4 165 in 9 ms); "tokens" =
`TOKEN_COUNT` of parser.c; "LR states" and "symbols" are tree-sitter's
generated numbers after merging; "scanner LOC" counts `scanner.c`/`.cc`
(+ `common/scanner.h` for typescript/tsx).

| language | rules | rule nodes | tokens | externals | scanner LOC | conflicts | inline | supertypes | LR states | symbols | grammar.json KB | ABI |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| c | 137 | 1574 | 128 | 0 | - | 8 | 7 | 7 | 1466 | 266 | 153 | 13 |
| cpp | 312 | 4165 | 222 | 2 | 148 | 35 | 7 | 7 | 8838 | 552 | 427 | 14 |
| rust | 180 | 2248 | 155 | 10 | 393 | 9 | 8 | 6 | 3649 | 346 | 212 | 14 |
| go | 116 | 1612 | 93 | 0 | - | 11 | 6 | 5 | 1269 | 211 | 183 | 14 |
| python | 148 | 1478 | 108 | 12 | 528 | 8 | 6 | 6 | 2819 | 270 | 139 | 14 |
| javascript | 141 | 1532 | 131 | 3 | 187 | 14 | 15 | 5 | 1576 | 256 | 157 | 14 |
| typescript | 225 | 2519 | 161 | 5 | 228 | 66 | 15 | 6 | 4345 | 368 | 261 | 14 |
| tsx | 225 | 2519 | 166 | 5 | 228 | 66 | 15 | 6 | 4524 | 382 | 261 | 14 |
| java | 154 | 1718 | 130 | 0 | - | 12 | 5 | 10 | 1282 | 292 | 162 | 13 |
| kotlin | 190 | 1497 | 153 | 7 | 543 | 26 | 0 | 0 | 12324 | 357 | 138 | 14 |
| lua | 66 | 724 | 72 | 6 | 194 | 0 | 0 | 4 | 262 | 137 | 72 | 14 |
| bash | 101 | 1666 | 175 | 29 | 1217 | 6 | 11 | 3 | 7671 | 280 | 175 | 14 |
| json | 13 | 161 | 15 | 0 | - | 0 | 0 | 1 | 32 | 25 | 19 | 13 |
| yaml | 202 | 1450 | 106 | 105 | 981 | 14 | 27 | 0 | 1579 | 293 | 151 | 13 |
| toml | 27 | 196 | 40 | 5 | 91 | 0 | 0 | 0 | 152 | 66 | 18 | 13 |
| html | 19 | 105 | 25 | 9 | 362 | 0 | 0 | 0 | 94 | 41 | 9 | 14 |
| css | 53 | 410 | 52 | 1 | 52 | 1 | 2 | 0 | 278 | 102 | 36 | 13 |
| markdown | 80 | 1242 | 91 | 47 | 1597 | 3 | 0 | 0 | 925 | 204 | 155 | 14 |
| markdown_inline | 79 | 1428 | 67 | 15 | 397 | 57 | 0 | 0 | 1160 | 148 | 192 | 14 |
| sql | 612 | 4763 | 410 | 3 | 189 | 5 | 0 | 0 | 14876 | 721 | 513 | 14 |
| dockerfile | 60 | 458 | 87 | 5 | 318 | 0 | 0 | 0 | 325 | 164 | 42 | 14 |
| make | 64 | 941 | 111 | 0 | - | 0 | 9 | 0 | 1286 | 176 | 97 | 13 |
| diff | 17 | 112 | 31 | 0 | - | 0 | 0 | 0 | 53 | 47 | 9 | 14 |

## Difficulty

Difficulty is the work to reach exact-tree equality with tree-sitter on valid
files, from 1 (trivial) to 5 (very hard), combining the table (size, conflicts,
state blow-up over the LR(0) count), the lexer (patterns, immediate tokens,
`word`), and above all the scanner (SPEC 6.2). In implementation order:

| language | difficulty | scanner | notes |
|---|---|---|---|
| json | 1 (trivial) | none | Smallest grammar (13 rules, 32 states). `comment` is an extra. Nested `string_content` -> `escape_sequence` depends on the revision (SPEC 2.1). The g1 vehicle. |
| diff | 1 (trivial) | none | 17 rules, 53 states; line-oriented, 11 IMMEDIATE_TOKEN uses. Tiny, but its highlight queries lean on `injections` of the diff content. |
| lua | 2 (easy) | 6 externals, level counter | 66 rules, 262 states, no conflicts. Scanner: `[==[` long strings and comments (one byte of state). Needs `\p{Control}`. Second target after json. |
| toml | 2 (easy) | 5 externals, stateless | 27 rules, 152 states. Scanner only ends multi-line strings. 10 IMMEDIATE_TOKEN uses. Needs the scanner for correct multi-line strings. |
| css | 2 (easy) | 1 external, stateless | 53 rules, 278 states, 1 conflict. One scanner token (descendant combinator). Used as an injection target in html/markdown. |
| make | 2 (easy) | none | 64 rules, 1 286 states, `word = word`, 9 inline rules, 111 IMMEDIATE_TOKEN mentions (shell recipes, variable references). Surprisingly large table for its size. |
| c | 2 (easy) | none | 137 rules, 1 466 states, 8 conflicts, 9 PREC_DYNAMIC. No scanner. The best first real language: realistic, queries exist in both families (highlights, indents, injections, folds, textobjects in Helix). |
| go | 2 (easy) | none | 116 rules, 1 269 states, 11 conflicts. No scanner. Statement terminators are the `"\n"` and `";"` tokens, resolved by context-aware lexing (SPEC 6.2). Needs `\p{L}`. |
| java | 2 (easy) | none | 154 rules, 1 282 states, 12 conflicts, 10 supertypes, no `inline`. No scanner. `\p{L}`, `\p{Nd}`. |
| javascript | 3 (medium) | 3 externals, stateless | 141 rules, 1 576 states, 14 conflicts, 15 inline, 7 named-precedence lists. Scanner: ASI, template chars, ternary `?`. Doubles as the base of typescript/tsx; injections (jsdoc, regex, html/css/sql in tagged templates, in queries). |
| typescript | 4 (hard) | 5 externals, shared scanner.h | 225 rules, 4 345 states, **66 conflicts**, 36 named-precedence lists, 15 inline. The grammar that stresses the table builder (conflict handling, precedence names). Scanner = the JavaScript one plus two tokens. |
| tsx | 4 (hard) | 5 externals, shared scanner.h | typescript plus JSX: 4 524 states. Same scanner. Free once typescript works. |
| rust | 3 (medium) | 10 externals, 1 byte of state | 180 rules, 3 649 states, 9 conflicts. Scanner: raw strings, float literals (`1.` vs `1..2`), doc-comment markers and content, nested block comments. Needs `XID_Start`/`XID_Continue`. Injections in nvim's `injections.scm` include comments, and rust code inside some macros. |
| python | 4 (hard) | 12 externals, indent and delimiter stacks | 148 rules, 2 819 states (2.6x the LR(0) count), 8 conflicts. Scanner: offside rule and f-strings; six of the 12 externals exist only for error recovery. Needs XID classes. |
| cpp | 4 (hard) | 2 externals, delimiter string | **312 rules, 8 838 states**, 35 conflicts, 26 PREC_DYNAMIC, inherits c. The scanner is easy (raw strings), the table is the cost: ~12 MB at m31 widths and the longest build. Needs XID classes. |
| kotlin | 4 (hard) | 7 externals, string-delimiter stack | 190 rules but **12 324 states** (5.2x LR(0)), 26 conflicts, no inline, no supertypes, `word = _alpha_identifier`. Hardest table per rule in the set. Scanner: ASI, nested comments, string interpolation. Queries: Helix has no textobjects or indents for it (folds, highlights, injections, locals only). |
| html | 3 (medium) | 9 externals, tag stack | 19 rules, 94 states: the grammar is trivial and the scanner carries the language (implicit end tags, void elements, raw text). Injection **host** for css and javascript: needs injections to be useful at all. |
| dockerfile | 3 (medium) | 5 externals, heredoc list | 60 rules, 325 states, 38 IMMEDIATE_TOKEN mentions. Scanner: heredocs. Injection host (bash in `RUN`, per the nvim and Helix `injections.scm`). |
| sql | 4 (hard) | 3 externals, dollar-quote tag | **612 rules, 14 876 states**, 410 tokens, 5 conflicts, `word = _identifier`. Scanner is easy. The largest table in the set; keywords are written as case-insensitive patterns (`[sS][eE][lL][eE][cC][tT]`), so the lexer has hundreds of near-identical class sequences. |
| markdown_inline | 4 (hard) | 15 externals | 79 rules, 1 160 states, **57 conflicts**, 28 PREC_DYNAMIC. Scanner: CommonMark emphasis flanking, code spans, latex spans. Only meaningful as an injected tree. |
| bash | 5 (very hard) | 29 externals, heredoc stack | 101 rules, 7 671 states, 30 IMMEDIATE_TOKEN mentions, `word = word`. 1 217-line scanner (heredocs, expansions, test operators, regexes, extglobs). The scanner is the work. |
| yaml | 5 (very hard) | 105 externals, C++, indent stack | 202 rules, 1 579 states, 14 conflicts, 27 inline. The 105 external tokens are the YAML 1.2 grammar split by context; the 981-line C++ scanner is the real parser. Candidate to stay on the lexical highlighter. |
| markdown | 5 (very hard) | 47 externals, container-block stack | 80 rules, 925 states, 3 precedence lists. 1 597-line scanner for CommonMark block structure. Host for `markdown_inline` (inline layer is a second tree over `inline` nodes), for fenced code (any language), and for front matter (yaml/toml). Candidate to stay lexical until injections work. |

## What follows from the survey

- **No scanner (6 grammars):** json, diff, c, go, java, make. These work with
  g1-g4 alone and are the first half of the oracle corpus.
- **Stateless or tiny-state scanners (5 easy ports):** css, toml, lua, cpp, sql.
- **The tables that cost the most** are not the scanner-heavy languages:
  kotlin (12 324 states from 190 rules), sql (14 876), cpp (8 838), bash
  (7 671). These decide the table-build time and memory budget (SPEC 3.1, 3.6).
- **The grammars that need `\p{..}`:** cpp, rust, python (XID_Start/XID_Continue),
  go (L), java and kotlin (L, Nd), javascript/typescript/tsx (Zs), lua (Control).
  Nothing else does; the six properties are the whole Unicode requirement of
  g0.
- **`word` is set in 14 of 23** (c, cpp, rust, go, python, javascript,
  typescript, tsx, java, kotlin, lua, bash, sql, make); keyword extraction must
  be in g1 for c.
- **Injection hosts:** markdown (-> markdown_inline, any fenced language,
  yaml/toml front matter), html (-> css, javascript), javascript/typescript
  (jsdoc, html/css/sql/graphql in tagged templates), rust (doc comments ->
  markdown), c/cpp/java/etc. (comments -> comment/doc languages), dockerfile
  and make (-> bash). Injections are a g5 feature but the tree API must carry
  *included ranges* from g2 on.
- **Supertypes:** present in 13 grammars (1 in json, 3 in bash, 4 in lua, 5 to
  7 in c, cpp, rust, go, python, javascript, typescript, tsx, 10 in java);
  the others have none. They are hidden nodes
  usable in queries; the tree needs the supertype map from the start (g1).
- **`PREC_DYNAMIC`:** used in c (9), cpp (26), go, java, javascript, typescript,
  python, bash, markdown (3), markdown_inline (28). GLR version selection is
  needed for these (g4 for c).

## Query files available (Helix runtime and nvim-treesitter, 23 languages)

| kind | Helix | nvim-treesitter |
|---|--:|--:|
| highlights | 22 | 23 |
| injections | 19 | 22 |
| indents | 15 | 17 |
| textobjects | 16 | 0 (separate plugin, not installed) |
| folds | 2 | 21 |
| locals | 7 | 16 |

(`experiments/query_survey.py`.) Textobjects exist only in Helix's tree, folds
only in nvim-treesitter's: a combination of both families is unavoidable
unless the owner writes some (QUESTIONS 5).
