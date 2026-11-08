# tree-sitter's own table sizes for the 23 languages, from parser.c.
#   GROVE_GRAMMARS=/dir/of/grammar/sources python3 -I experiments/table_sizes.py
# Dense size = LARGE_STATE_COUNT x SYMBOL_COUNT x 2 bytes (the u16 table of large states).
import os, re

ROOT = os.environ.get('GROVE_GRAMMARS', '/home/nox/homelab/apps/nox/runtime/grammars/sources')
SUB = {'typescript': 'typescript/typescript', 'tsx': 'tsx/tsx', 'markdown': 'markdown/tree-sitter-markdown',
       'markdown_inline': 'markdown_inline/tree-sitter-markdown-inline'}
for name in "c cpp rust go python javascript typescript tsx java kotlin lua bash json yaml toml html css markdown markdown_inline sql dockerfile make diff".split():
    text = open(ROOT + '/' + SUB.get(name, name) + '/src/parser.c', errors='ignore').read()
    get = lambda key: int(re.search(r'#define ' + key + r' (\d+)', text).group(1))
    states, large, symbols = get('STATE_COUNT'), get('LARGE_STATE_COUNT'), get('SYMBOL_COUNT')
    print("%-16s states=%6d large=%5d symbols=%4d dense=%6d KB parser.c=%6d KB" % (
        name, states, large, symbols, large * symbols * 2 // 1024, len(text) // 1024))
