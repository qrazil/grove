# Changelog

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
