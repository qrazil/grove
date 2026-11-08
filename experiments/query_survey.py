# Which predicates, directives and structures the real query files use, for the 23 languages.
#   python3 -I experiments/query_survey.py [HELIX_QUERIES] [NVIM_TREESITTER_QUERIES]
import collections, os, re, sys

HELIX = sys.argv[1] if len(sys.argv) > 1 else '/usr/lib64/helix/runtime/queries'
NVIM = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser('~/.local/share/nvim/lazy/nvim-treesitter/queries')
LANGS = "c cpp rust go python javascript typescript tsx java kotlin lua bash json yaml toml html css markdown markdown_inline sql dockerfile make diff".split()
FEATURES = [('alternation [', lambda t: t.count('[')), ('wildcard (_)', lambda t: t.count('(_)')),
            ('anchor .', lambda t: len(re.findall(r'(?<![\w@#])\.(?![\w])', t))),
            ('field:', lambda t: len(re.findall(r'\w+:\s*[\(\["]', t))),
            ('negated !field', lambda t: len(re.findall(r'\s!\w+', t))),
            ('quantified + * ?', lambda t: len(re.findall(r'[\)\]"@\w][+*?]\s', t))),
            ('(ERROR', lambda t: t.count('(ERROR')), ('MISSING', lambda t: t.count('MISSING')),
            ('supertype/sub', lambda t: len(re.findall(r'\(\w+/\w+\)', t))),
            ('private @_x', lambda t: len(re.findall(r'@_', t)))]
for label, root in (('helix', HELIX), ('nvim-treesitter', NVIM)):
    predicates, features, files, lines = collections.Counter(), collections.Counter(), collections.Counter(), 0
    for lang in LANGS:
        folder = root + '/' + lang
        if not os.path.isdir(folder):
            continue
        for name in os.listdir(folder):
            if not name.endswith('.scm'):
                continue
            text = re.sub(r';.*', '', open(folder + '/' + name).read())
            files[name] += 1
            lines += text.count('\n')
            for m in re.findall(r'\(#(not-)?([a-z\-]+[?!]?)', text):
                predicates['#' + m[0] + m[1]] += 1
            for feature, count in FEATURES:
                features[feature] += count(text)
    print(label, 'files', sum(files.values()), 'lines', lines)
    print('  per file kind:', dict(sorted(files.items())))
    print('  predicates:', dict(predicates.most_common()))
    print('  structures:', dict(features))
