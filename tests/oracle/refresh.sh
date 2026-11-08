#!/usr/bin/env bash
# Regenerate tree-sitter's side of the oracle (tests/oracle/ts/*.sexp) for the
# files in a manifest, with the local nvim.
#
#   GROVE_PARSER_DIR=/dir/with/json.so bash tests/oracle/refresh.sh [MANIFEST]
#
# A grammar.json describes ONE revision of a grammar; the parser that dumps the
# oracle must be built from that same revision (GROVE_PARSER_DIR), or the trees
# differ in ways that are not grove's fault (seen: tree-sitter-json moved
# escape_sequence out of string_content between two revisions). Without
# GROVE_PARSER_DIR, nvim-treesitter's parsers are used (NVIM_TS_RTP).
# Only the .sexp files under tests/oracle/ts are written.
set -euo pipefail
cd "$(dirname "$0")/../.."
MANIFEST=${1:-tests/oracle/fixtures.tsv}
OUT=${TS_DIR:-tests/oracle/ts}
mkdir -p "$OUT"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
awk -F'\t' '!/^#/ && NF >= 2 { print $1 "\t" $2 }' "$MANIFEST" > "$work/ts.tsv"
nvim -u NONE --headless -l tests/oracle/dump_sexp.lua "$work/ts.tsv" "$OUT"
echo "dumped $(wc -l < "$work/ts.tsv") files into $OUT"
