#!/usr/bin/env bash
# The many-file oracle for queries: grove's captures against nvim's, over real files, nothing committed.
#
#   M31_ROOT=... LANGC=... GROVE_PARSER_DIR=DIR_WITH_LANG.so \
#     bash tests/oracle/report_captures.sh LANG GRAMMAR.json QUERY.scm MAX_FILES MAX_BYTES DIR [DIR ...]
#
# Same file choice as report.sh. nvim runs QUERY over each file with the parser of the same revision as
# GRAMMAR.json; QUERY must load in that parser (nvim refuses a node type the grammar lacks). Files nvim
# cannot query, or that grove parses with errors, are skipped.
set -euo pipefail
cd "$(dirname "$0")/../.."
lang=$1; grammar=$2; query=$3; max_files=$4; max_bytes=$5; shift 5
case "$lang" in
    json) pattern='*.json' ;;
    c) pattern='*.[ch]' ;;
    lua) pattern='*.lua' ;;
    *) echo "unknown language $lang" >&2; exit 2 ;;
esac
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
. "$M31_ROOT/runtime/arch.sh"
"$LANGC" -emit-c tests/oracle/dump_captures.m31 --out "$work/dump.c"
cc -O2 -w -I "$M31_ROOT/runtime" -pthread -o "$work/dump" "$work/dump.c" \
    "$M31_ROOT/runtime/rt.c" "$M31_ROOT/runtime/scheduler.c" "$M31_ROOT/$RT_REACTOR_C" "$M31_ROOT/$RT_CTX_ASM"
find "$@" -type f -name "$pattern" -size -"${max_bytes}"c -size +0c 2>/dev/null \
    | while read -r f; do printf '%s %s\n' "$(printf '%s' "$f" | cksum | cut -d' ' -f1)" "$f"; done \
    | sort -n > "$work/ranked.txt" || true
head -n "$max_files" "$work/ranked.txt" | cut -d' ' -f2- > "$work/files.txt"
awk -v l="$lang" -v q="$query" '{ print l "\t" q "\t" $0 }' "$work/files.txt" > "$work/manifest.tsv"
mkdir -p "$work/ts"
nvim -u NONE --headless -l tests/oracle/dump_captures.lua "$work/manifest.tsv" "$work/ts"
python3 tests/oracle/compare_captures.py --quiet --dump "$work/dump" --grammar "$grammar" --query "$query" --ts-dir "$work/ts" "@$work/files.txt"
