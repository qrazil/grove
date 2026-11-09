#!/usr/bin/env bash
# Regenerate nvim's side of the query oracle for the fixtures of tests/oracle/fixtures.tsv:
#
#   tests/oracle/cap/            captures of the highlights (tests/data/queries/LANG.scm)
#   tests/oracle/cap_KIND/       captures of textobjects, folds, injections (tests/data/queries/KIND/LANG.scm)
#   tests/oracle/ind/            nvim-treesitter's indentation of every line (tests/data/queries/indents/LANG.scm)
#
#   GROVE_PARSER_DIR=/dir/with/json.so,c.so,lua.so NVIM_TS=/path/to/nvim-treesitter bash tests/oracle/refresh_captures.sh
#
# The parsers must be built from the same revision as tests/data/LANG/grammar.json (see refresh.sh).
set -euo pipefail
cd "$(dirname "$0")/../.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
dump() { # KIND QUERY_DIR OUT
    local kind=$1 dir=$2 out=$3
    mkdir -p "$out"
    awk -F'\t' -v d="$dir" '!/^#/ && NF >= 2 { print $1 "\t" d "/" $1 ".scm\t" $2 }' tests/oracle/fixtures.tsv \
        | while IFS=$'\t' read -r lang query path; do [ -f "$query" ] && printf '%s\t%s\t%s\n' "$lang" "$query" "$path"; done > "$work/$kind.tsv"
    nvim -u NONE --headless -l tests/oracle/dump_captures.lua "$work/$kind.tsv" "$out"
    echo "$kind: $(wc -l < "$work/$kind.tsv") files into $out"
}
dump highlights tests/data/queries tests/oracle/cap
for kind in textobjects folds injections; do
    dump "$kind" "tests/data/queries/$kind" "tests/oracle/cap_$kind"
done
mkdir -p tests/oracle/ind
awk -F'\t' '!/^#/ && NF >= 2 { print $1 "\ttests/data/queries/indents/" $1 ".scm\t" $2 }' tests/oracle/fixtures.tsv > "$work/ind.tsv"
nvim -u NONE --headless -l tests/oracle/dump_indent.lua "$work/ind.tsv" tests/oracle/ind
echo "indent: $(wc -l < "$work/ind.tsv") files into tests/oracle/ind"
