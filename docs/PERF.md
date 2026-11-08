# Performance

Numbers, with the machine and tool that produced them. A time is not a fixture:
nothing in `tests/test.sh` compares them.

## tree-sitter through nvim (baseline)

nvim 0.11.5, nvim-treesitter parsers, injections off, `experiments/ts_bench.lua`.
Cold parse of the whole buffer, then 20 one-character insertions at line starts
in the middle of the buffer, each followed by a reparse. The edit time includes
nvim's own bookkeeping (`LanguageTree`, on_bytes), which was not separated.

| file | bytes | cold parse | nodes | edit + reparse avg / worst |
|---|--:|--:|--:|--:|
| JSON (generated, 9 000 records) | 1 727 103 | 341 ms | 846 003 | 15.6 / 16.5 ms |
| C (libbpf.c repeated 4 times) | 1 543 352 | 317 ms | 424 509 | 22.7 / 28.4 ms |
| Python (Cython ExprNodes.py) | 602 442 | 111 ms | 128 444 | 2.0 / 4.8 ms |
| Rust (core/src/slice/mod.rs) | 219 064 | 30 ms | 41 016 | 12.3 / 15.2 ms |

With injections on (nvim's default for `parse(true)`) the C case was 154 ms per
edit (every comment is an injected tree).

## grove prototype (m31 v0.14.2, cc -O2, one core)

`tests/bench.m31`. Loading = read grammar.json + lower to the rule arena.

| grammar.json | bytes | JSON nodes | rule nodes | read | read + lower |
|---|--:|--:|--:|--:|--:|
| json | 19 469 | 479 | 163 | 0 ms | 0 ms |
| c | 156 734 | 4 707 | 1 576 | 2 ms | 2 ms |
| typescript | 267 315 | 8 033 | 2 521 | 4 ms | 4 ms |
| cpp | 437 528 | 12 438 | 4 167 | 8 ms | 9 ms |
| sql | 526 092 | 14 100 | 4 767 | 7 ms | 9 ms |

PEG interpreter (not the design) on 113 215 bytes of JSON (600 records):
25 802 tree nodes in 255 ms, 0.44 MB/s, with the position-set matcher and no
DFA. It is the floor the real lexer has to beat by an order of magnitude.

## Table sizes (tree-sitter's, from parser.c)

`experiments/results/table_sizes.txt`; the LR(0) automaton sizes in
`experiments/results/lr0_estimate.txt`.

## grove g1 (0.1.0): tables and parse

Same machine and toolchain as above. Full numbers and the reading in
`docs/SPEC.md` section 14; recorded in `experiments/results/table_build.txt`.

| what | result |
|---|---|
| LR(1) tables, json / lua / c | under 1 ms / 45 ms / 463 ms |
| LR(1) tables, typescript / cpp / sql | 2.5 s / 1.7 s / 3.8 s |
| table size (Array of int) | 1 KB json, 64 KB lua, 770 KB c, 2.7 MB typescript |
| GLR parse, 1.7 MB generated JSON | 1.08 s (1.6 MB/s); tree-sitter in nvim 0.34 s |
| GLR parse, 608 KB C | 0.39 s |
| lexer DFA states built lazily | 49 (JSON file), 279 (C file) |
