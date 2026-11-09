#!/usr/bin/env bash
# Regenerate nvim's side of the query oracle (tests/oracle/cap/*.cap) for the fixtures of
# tests/oracle/fixtures.tsv, using tests/data/queries/LANG.scm.
#
#   GROVE_PARSER_DIR=/dir/with/json.so,c.so,lua.so bash tests/oracle/refresh_captures.sh
#
# The parsers must be built from the same revision as tests/data/LANG/grammar.json (see refresh.sh).
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=tests/oracle/cap
mkdir -p "$OUT"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
awk -F'\t' '!/^#/ && NF >= 2 { print $1 "\ttests/data/queries/" $1 ".scm\t" $2 }' tests/oracle/fixtures.tsv > "$work/manifest.tsv"
nvim -u NONE --headless -l tests/oracle/dump_captures.lua "$work/manifest.tsv" "$OUT"
echo "dumped $(wc -l < "$work/manifest.tsv") files into $OUT"
