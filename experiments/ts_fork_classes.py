# The forks of tree-sitter's tables by class: a class is the sorted list of actions (S = shift,
# R:rule:length = reduce; repeat rules are AUX), with how many (state, lookahead) pairs have it.
#   python3 -I experiments/ts_fork_classes.py LANG [SUBDIR]
# `tests/forks.m31` prints the same for grove's tables; experiments/compare_forks.sh compares them.
import os,sys,collections,re
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from ts_forks import load,R
name=sys.argv[1]; sub=sys.argv[2] if len(sys.argv)>2 else name
acts,pairs,syms,tc=load(f'{R}/{sub}')
def norm(s):
    s=re.sub(r'^sym_','',s)
    if s.startswith('aux_sym_'): return 'AUX'
    return s
out=collections.Counter()
for st,sy,a in pairs:
    c,l=acts[a]
    if c>1:
        parts=[]
        for k,v in l:
            f=v.split(',')
            if k=='REDUCE': parts.append('R:'+norm(f[0])+':'+f[1].strip())
            elif k.startswith('SHIFT'): parts.append('S')
        out[' | '.join(sorted(parts))]+=1
for k,v in sorted(out.items(),key=lambda x:-x[1]): print(v,k)
