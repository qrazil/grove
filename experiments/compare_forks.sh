#!/usr/bin/env bash
# Compare the forks of grove's tables with those in tree-sitter's parser.c, by class.
#
#   M31_ROOT=... LANGC=... GROVE_GRAMMARS=DIR bash experiments/compare_forks.sh c:c typescript:typescript/typescript ...
#
# Each argument is NAME:SUBDIR (the directory of the grammar under GROVE_GRAMMARS). Prints, per grammar,
# tree-sitter's non-repeat forks and grove's, and the classes only one of them has.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=${GROVE_GRAMMARS:-/home/nox/homelab/apps/nox/runtime/grammars/sources}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
. "$M31_ROOT/runtime/arch.sh"
"$LANGC" -emit-c tests/forks.m31 --out "$work/forks.c"
cc -O2 -w -I "$M31_ROOT/runtime" -pthread -o "$work/forks" "$work/forks.c" "$M31_ROOT/runtime/rt.c" \
    "$M31_ROOT/runtime/scheduler.c" "$M31_ROOT/$RT_REACTOR_C" "$M31_ROOT/$RT_CTX_ASM"
for pair in "$@"; do
    name=${pair%%:*}; sub=${pair#*:}
    "$work/forks" "$ROOT/$sub/src/grammar.json" > "$work/ours.txt"
    GROVE_GRAMMARS=$ROOT python3 -I experiments/ts_fork_classes.py "$name" "$sub" > "$work/ts.txt"
    python3 -I - "$name" "$work/ours.txt" "$work/ts.txt" <<'PY'
import collections, re, sys
name, ours_file, ts_file = sys.argv[1:4]
def read(path, skip_forks_line):
    out = collections.Counter()
    for line in open(path):
        m = re.match(r'(\d+) (.*)', line.strip())
        if m and not (skip_forks_line and line.startswith('forks')):
            out[m.group(2)] += int(m.group(1))
    return out
ours, ts = read(ours_file, True), read(ts_file, False)
real = lambda c: {k: v for k, v in c.items() if k != 'R:AUX:2 | S'}
o, t = real(ours), real(ts)
print("%s: tree-sitter %d forks (%d of them repeat shift/reduce), non-repeat %d in %d classes; grove %d in %d classes; only in grove %d classes/%d forks; only in tree-sitter %d/%d" % (
    name, sum(ts.values()), ts.get('R:AUX:2 | S', 0), sum(t.values()), len(t), sum(o.values()), len(o),
    len(set(o) - set(t)), sum(o[k] for k in set(o) - set(t)), len(set(t) - set(o)), sum(t[k] for k in set(t) - set(o))))
for k in sorted(set(o) - set(t), key=lambda k: -o[k])[:4]:
    print("    only in grove: %d %s" % (o[k], k[:100]))
for k in sorted(set(t) - set(o), key=lambda k: -t[k])[:3]:
    print("    only in tree-sitter: %d %s" % (t[k], k[:100]))
PY
done
