#!/usr/bin/env python3
"""Compare grove's query captures with nvim's.

  compare_captures.py --dump GROVE_DUMP_CAPTURES --grammar G.json --query Q.scm --ts-dir DIR PATH...

DIR holds nvim's dumps (`PATH.cap`, made by dump_captures.lua). Both sides are reduced to the set of
(name, range) and compared; the number of repeats of the same capture is reported separately because
the order and multiplicity of matches is not something a highlighter uses. A file nvim could not
query, or that grove parses with errors, is skipped. Exits 1 on any difference.
"""
import argparse, os, subprocess, sys


def read(text):
    rows = []
    for line in text.split('\n')[1:]:
        if not line.strip() or line.startswith('!!'):
            continue
        parts = line.split(' ')
        rows.append((parts[0],) + tuple(int(x) for x in parts[1:5]))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dump', required=True)
    ap.add_argument('--grammar', required=True)
    ap.add_argument('--query', required=True)
    ap.add_argument('--ts-dir', required=True)
    ap.add_argument('--quiet', action='store_true')
    ap.add_argument('paths', nargs='+')
    args = ap.parse_args()
    paths = []
    for p in args.paths:
        paths += [l.rstrip('\n') for l in open(p[1:]) if l.strip()] if p.startswith('@') else [p]
    want = {}
    for p in paths:
        f = os.path.join(args.ts_dir, p.replace('/', '__') + '.cap')
        if os.path.exists(f):
            text = open(f).read()
            if '!!' not in text:
                want[p] = read(text)
    todo = [p for p in paths if p in want]
    out = subprocess.run([args.dump, args.grammar, args.query] + todo, capture_output=True, text=True).stdout
    got, current, bad = {}, None, set()
    for line in out.split('\n'):
        if line.startswith('@@ '):
            current = line[3:]
            got[current] = ['@@']
        elif line.startswith('!! '):
            bad.add(line[3:].split(':')[0])
        elif current is not None and line.strip():
            got[current].append(line)
    same = diff = 0
    for p in todo:
        if p in bad:
            continue
        ours = read('\n'.join(got.get(p, ['@@'])))
        theirs = want[p]
        if set(ours) == set(theirs):
            same += 1
            if len(ours) != len(theirs) and not args.quiet:
                print('same set, %d vs %d captures: %s' % (len(ours), len(theirs), p))
        else:
            diff += 1
            only_ours = sorted(set(ours) - set(theirs))[:3]
            only_theirs = sorted(set(theirs) - set(ours))[:3]
            print('DIFF', p)
            print('     only grove:', only_ours)
            print('     only nvim :', only_theirs)
    print('%d identical sets, %d different, %d skipped' % (same, diff, len(paths) - same - diff))
    sys.exit(1 if diff else 0)


main()
