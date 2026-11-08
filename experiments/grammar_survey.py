# Statistics of the grammar.json / parser.c of the 23 target languages.
#   GROVE_GRAMMARS=/dir/of/grammar/sources python3 -I experiments/grammar_survey.py
# Prints one markdown table row per language (rules, rule nodes, tokens, externals, scanner LOC,
# conflicts, inline, supertypes, LR states, symbols, grammar.json KB, ABI) and the
# rule-type / pattern-feature census quoted in docs/SPEC.md.
import json, os, re, collections

ROOT = os.environ.get('GROVE_GRAMMARS', '/home/nox/homelab/apps/nox/runtime/grammars/sources')
SUB = {'typescript': 'typescript/typescript', 'tsx': 'tsx/tsx', 'markdown': 'markdown/tree-sitter-markdown',
       'markdown_inline': 'markdown_inline/tree-sitter-markdown-inline'}
NAMES = "c cpp rust go python javascript typescript tsx java kotlin lua bash json yaml toml html css markdown markdown_inline sql dockerfile make diff".split()


def census(rule, kinds, patterns):
    kinds[rule['type']] += 1
    if rule['type'] == 'PATTERN':
        patterns.append(rule['value'])
    if 'content' in rule:
        census(rule['content'], kinds, patterns)
    for member in rule.get('members', []):
        census(member, kinds, patterns)


kinds = collections.Counter()
patterns = []
print("| language | rules | rule nodes | tokens | externals | scanner LOC | conflicts | inline | supertypes | LR states | symbols | grammar.json KB | ABI |")
print("|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|")
for name in NAMES:
    base = ROOT + '/' + SUB.get(name, name)
    grammar = json.load(open(base + '/src/grammar.json'))
    own = collections.Counter()
    for rule in grammar['rules'].values():
        census(rule, own, patterns)
    kinds.update(own)
    parser_c = open(base + '/src/parser.c', errors='ignore').read()
    define = lambda key: int(re.search(r'#define ' + key + r' (\d+)', parser_c).group(1))
    scanners = [f for f in os.listdir(base + '/src') if f.startswith('scanner')]
    loc = sum(len(open(base + '/src/' + f, errors='ignore').readlines()) for f in scanners)
    if name in ('typescript', 'tsx'):
        loc += len(open(ROOT + '/typescript/common/scanner.h').readlines())
    print("| %s | %d | %d | %d | %d | %s | %d | %d | %d | %d | %d | %d | %s |" % (
        name, len(grammar['rules']), sum(own.values()), define('TOKEN_COUNT'), len(grammar.get('externals', [])),
        loc or '-', len(grammar.get('conflicts', [])), len(grammar.get('inline', [])),
        len(grammar.get('supertypes', [])), define('STATE_COUNT'), define('SYMBOL_COUNT'),
        os.path.getsize(base + '/src/grammar.json') // 1024, re.search(r'LANGUAGE_VERSION (\d+)', parser_c).group(1)))
print()
print("rule types:", dict(kinds.most_common()))
features = [('class [', r'\['), ('\\d \\w \\s', r'\\[dwsDWS]'), ('{n,m}', r'\{\d'), ('dot', r'(?<!\\)\.'), ('\\p{..}', r'\\p\{'),
            ('\\u escapes', r'\\u'), ('(?:', r'\(\?:'), ('lookaround (?= (?! (?<', r'\(\?[=!<]'), ('backreference', r'\\\d'), ('\\b', r'\\b')]
print("pattern features (of %d PATTERN rules):" % len(patterns),
      {name: sum(1 for p in patterns if re.search(rx, p)) for name, rx in features})
