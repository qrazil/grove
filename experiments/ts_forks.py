# Read tree-sitter's generated tables out of a grammar's src/parser.c and count the (state, lookahead)
# pairs that keep several actions (the forks of the GLR parser). Decodes ts_parse_actions, the large
# table ts_parse_table and the small table ts_small_parse_table.
#   python3 -I experiments/ts_forks.py LANG [SUBDIR]
import re,sys,collections,json
import os
R=os.environ.get('GROVE_GRAMMARS','/home/nox/homelab/apps/nox/runtime/grammars/sources')
def load(path):
    t=open(path+'/src/parser.c',errors='ignore').read()
    # actions
    m=re.search(r'ts_parse_actions\[\] = \{(.*?)\n\};',t,re.S)
    acts={}
    for i,c,body in re.findall(r'\[(\d+)\] = \{\.entry = \{\.count = (\d+), \.reusable = \w+\}\},?([^\[]*)',m.group(1)):
        acts[int(i)]=(int(c),re.findall(r'(SHIFT_REPEAT|SHIFT_EXTRA|SHIFT|REDUCE|ACCEPT_INPUT|RECOVER)\(([^)]*)\)',body))
    # symbols
    syms={}
    tc=int(re.search(r'#define TOKEN_COUNT (\d+)',t).group(1))
    # large table
    pairs=[]  # (state, symbol name, action idx)
    lm=re.search(r'ts_parse_table\[LARGE_STATE_COUNT\]\[SYMBOL_COUNT\] = \{(.*?)\n\};',t,re.S)
    if lm:
        for sm in re.finditer(r'\[STATE\((\d+)\)\] = \{(.*?)\n  \},',lm.group(1),re.S):
            st=int(sm.group(1))
            for sym,a in re.findall(r'\[(\w+)\] = ACTIONS\((\d+)\)',sm.group(2)):
                pairs.append((st,sym,int(a)))
    # small table
    sm=re.search(r'ts_small_parse_table\[\] = \{(.*?)\n\};',t,re.S)
    mp=re.search(r'ts_small_parse_table_map\[\] = \{(.*?)\n\};',t,re.S)
    small_states={}
    for s,o in re.findall(r'\[SMALL_STATE\((\d+)\)\] = (\d+)',mp.group(1)): small_states[int(o)]=int(s)
    for off,body in re.findall(r'\[(\d+)\] = (\d+),?([^\[]*)',sm.group(1)) and [(a,b+c) for a,b,c in re.findall(r'\[(\d+)\] = (\d+),([^\[]*)',sm.group(1))]:
        pass
    for off,cnt,body in re.findall(r'\[(\d+)\] = (\d+),([^\[]*)',sm.group(1)):
        st=small_states.get(int(off))
        toks=re.findall(r'ACTIONS\((\d+)\)|STATE\((\d+)\)|(\w+)',body)
        # sequence: (ACTIONS(k)|STATE(n)|...), count, sym...
        items=[x for x in re.findall(r'(ACTIONS\(\d+\)|STATE\(\d+\)|\w+)',body)]
        i=0;g=0
        while i<len(items) and g<int(cnt):
            head=items[i]; n=int(items[i+1]); i+=2
            for k in range(n):
                sym=items[i+k]
                if head.startswith('ACTIONS'): pairs.append((st,sym,int(re.search(r'\d+',head).group())))
            i+=n; g+=1
    return acts,pairs,syms,tc
if __name__=='__main__':
    name=sys.argv[1]; sub=sys.argv[2] if len(sys.argv)>2 else name
    acts,pairs,syms,tc=load(f'{R}/{sub}')
    multi=[(s,sy,a) for s,sy,a in pairs if acts[a][0]>1]
    print(name,'term pairs',len(pairs),'fork pairs',len(multi))
    sig=collections.Counter()
    for s,sy,a in multi:
        sig[(tuple((k,v.split(',')[0]) for k,v in acts[a][1]))]+=1
    for k,v in sig.most_common(8): print(' ',v,k)
