#!/usr/bin/env python3
"""Compare grove's trees with tree-sitter's.

  compare.py --dump GROVE_DUMP_TREE --grammar GRAMMAR.json --ts-dir DIR [--lang L] PATH...

PATH are source files (an argument `@FILE` stands for the lines of FILE); DIR holds tree-sitter's dumps (`PATH.sexp`, slashes written
as `__`, made by dump_sexp.lua). Files whose tree-sitter dump contains ERROR or
MISSING are skipped (the oracle compares valid input only). Prints one line per
file and a summary; exits 1 if any compared file differs.
"""
import argparse, os, subprocess, sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dump', required=True)
    ap.add_argument('--grammar', required=True)
    ap.add_argument('--ts-dir', required=True)
    ap.add_argument('paths', nargs='+')
    ap.add_argument('--quiet', action='store_true')
    args = ap.parse_args()
    expanded = []
    for p in args.paths:
        if p.startswith('@'):
            expanded += [l.rstrip('\n') for l in open(p[1:]) if l.strip()]
        else:
            expanded.append(p)
    args.paths = expanded
    want = {}
    for p in args.paths:
        f = os.path.join(args.ts_dir, p.replace('/', '__') + '.sexp')
        if not os.path.exists(f):
            continue
        text = open(f).read()
        if 'ERROR' in text or 'MISSING' in text or text.startswith('!!'):
            continue
        want[p] = text.split('\n', 1)[1]
    paths = [p for p in args.paths if p in want]
    out = subprocess.run([args.dump, args.grammar] + paths, capture_output=True, text=True).stdout
    got, current = {}, None
    for line in out.split('\n'):
        if line.startswith('@@ '):
            current = line[3:]
            got[current] = []
        elif line.startswith('!! '):
            name = line[3:].split(': ')[0]
            got[name] = ['!!' + line]
        elif current is not None:
            got[current].append(line)
    same = diff = 0
    for p in paths:
        g = '\n'.join(got.get(p, ['(missing)'])).rstrip('\n')
        w = want[p].rstrip('\n')
        if g == w:
            same += 1
            if not args.quiet:
                print('ok   ', p)
        else:
            diff += 1
            gl, wl = g.split('\n'), w.split('\n')
            first = next((i for i in range(min(len(gl), len(wl))) if gl[i] != wl[i]), min(len(gl), len(wl)))
            print('DIFF ', p, 'line', first + 1)
            print('     ours:', gl[first] if first < len(gl) else '(end)')
            print('     want:', wl[first] if first < len(wl) else '(end)')
    print('%d identical, %d different, %d skipped (tree-sitter reports errors)' % (same, diff, len(args.paths) - len(paths)))
    sys.exit(1 if diff else 0)


main()
