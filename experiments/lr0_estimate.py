# usage: python3 -I experiments/lr0_estimate.py LANG [LANG ...]   (LANG is a directory under GROVE_GRAMMARS)
# Rough LR(0) size estimate of a grammar.json: flatten as tree-sitter does (cross product of
# SEQ/CHOICE, repeats to aux rules), count productions and LR(0) states. Not a parser generator.
import json,sys,time,itertools
import os
R=os.environ.get('GROVE_GRAMMARS','/home/nox/homelab/apps/nox/runtime/grammars/sources')
def run(path,cap=200000):
    g=json.load(open(path))
    ext={e['name'] for e in g.get('externals',[]) if e['type']=='SYMBOL'}
    prods=[]  # (lhs, tuple of syms)  terminals are ('t',key), nonterminals ('n',name)
    aux=[0]
    def key(r): return json.dumps(r,sort_keys=True)
    def alts(r,lhs):
        t=r['type']
        if t in('STRING','PATTERN','TOKEN','IMMEDIATE_TOKEN'): return [(('t',key(r)),)]
        if t=='BLANK': return [()]
        if t=='SYMBOL':
            n=r['name']
            return [(('t','ext:'+n),)] if n in ext else [(('n',n),)]
        if t in('FIELD','ALIAS','PREC','PREC_LEFT','PREC_RIGHT','PREC_DYNAMIC'): return alts(r['content'],lhs)
        if t=='CHOICE':
            out=[]
            for m in r['members']: out+=alts(m,lhs)
            return out
        if t=='SEQ':
            out=[()]
            for m in r['members']:
                a=alts(m,lhs)
                out=[x+y for x in out for y in a]
                if len(out)>cap: raise OverflowError
            return out
        if t in('REPEAT','REPEAT1'):
            aux[0]+=1;name=f'_aux{aux[0]}'
            a=alts(r['content'],lhs)
            for x in a: prods.append((name,x)); prods.append((name,(('n',name),)+x))
            return [(('n',name),)] + ([()] if t=='REPEAT' else [])
        raise ValueError(t)
    for name,r in g['rules'].items():
        for a in alts(r,name): prods.append((name,a))
    # dedupe
    prods=list(dict.fromkeys(prods))
    first=list(g['rules'])[0]
    prods.insert(0,('$start',(('n',first),)))
    by={}
    for i,(l,_) in enumerate(prods): by.setdefault(l,[]).append(i)
    clo_cache={}
    def closure(kernel):
        items=set(kernel);stack=list(kernel);seen=set()
        while stack:
            p,d=stack.pop();rhs=prods[p][1]
            if d<len(rhs) and rhs[d][0]=='n':
                n=rhs[d][1]
                if n in seen:continue
                seen.add(n)
                for q in by.get(n,()):
                    it=(q,0)
                    if it not in items: items.add(it);stack.append(it)
        return items
    start=frozenset([(0,0)]);states={start:0};work=[start]
    t0=time.time()
    while work:
        k=work.pop();items=closure(k);gos={}
        for p,d in items:
            rhs=prods[p][1]
            if d<len(rhs): gos.setdefault(rhs[d],set()).add((p,d+1))
        for sym,ks in gos.items():
            fk=frozenset(ks)
            if fk not in states: states[fk]=len(states);work.append(fk)
        if time.time()-t0>240: return len(prods),len(states),'timeout'
    return len(prods),len(states),f'{time.time()-t0:.1f}s'
if __name__=='__main__':
    for n in sys.argv[1:]:
        try: print(n,run(f'{R}/{n}/src/grammar.json'),flush=True)
        except OverflowError: print(n,'flatten blowup',flush=True)
