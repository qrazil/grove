#!/usr/bin/env bash
# The many-file oracle: grove against tree-sitter over real files, nothing committed.
#
#   M31_ROOT=... LANGC=... GROVE_PARSER_DIR=DIR_WITH_LANG.so \
#     bash tests/oracle/report.sh LANG GRAMMAR.json MAX_FILES MAX_BYTES FILE_GLOB_DIR [DIR ...]
#
# Lists the files under the DIRs whose name ends in the extension of LANG (json: .json,
# c: .c and .h), up to MAX_FILES of at most MAX_BYTES, sorted by a hash of the path so the
# choice is deterministic; dumps tree-sitter's trees with dump_sexp.lua (GROVE_PARSER_DIR
# must hold a parser built from the same revision as GRAMMAR.json), builds
# tests/oracle/dump_tree.m31 and runs compare.py. Files tree-sitter parses with errors are
# skipped. Prints the identical/different counts and the first differences.
set -euo pipefail
cd "$(dirname "$0")/../.."
lang=$1; grammar=$2; max_files=$3; max_bytes=$4; shift 4
case "$lang" in
    json) pattern='*.json' ;;
    c) pattern='*.[ch]' ;;
    *) echo "unknown language $lang" >&2; exit 2 ;;
esac
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
. "$M31_ROOT/runtime/arch.sh"
"$LANGC" -emit-c tests/oracle/dump_tree.m31 --out "$work/dump.c"
cc -O2 -w -I "$M31_ROOT/runtime" -pthread -o "$work/dump" "$work/dump.c" \
    "$M31_ROOT/runtime/rt.c" "$M31_ROOT/runtime/scheduler.c" "$M31_ROOT/$RT_REACTOR_C" "$M31_ROOT/$RT_CTX_ASM"
find "$@" -type f -name "$pattern" -size -"${max_bytes}"c -size +0c 2>/dev/null \
    | while read -r f; do printf '%s %s\n' "$(printf '%s' "$f" | cksum | cut -d' ' -f1)" "$f"; done \
    | sort -n > "$work/ranked.txt" || true
head -n "$max_files" "$work/ranked.txt" | cut -d' ' -f2- > "$work/files.txt"
awk -v l="$lang" '{ print l "\t" $0 }' "$work/files.txt" > "$work/manifest.tsv"
mkdir -p "$work/ts"
nvim -u NONE --headless -l tests/oracle/dump_sexp.lua "$work/manifest.tsv" "$work/ts"
python3 tests/oracle/compare.py --quiet --dump "$work/dump" --grammar "$grammar" --ts-dir "$work/ts" "@$work/files.txt"
