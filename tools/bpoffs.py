"""bpoffs.py CHKDIR STARTHEX ENDHEX: bp-relative offsets used in a proc range, orig vs built"""
import sys,capstone
md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_16); md.detail=True
d=sys.argv[1]; s,e=int(sys.argv[2],16),int(sys.argv[3],16)
def offs(buf):
    r={}
    for i in md.disasm(buf[s:e],s):
        for op in i.operands:
            if op.type==3 and op.mem.base==capstone.x86.X86_REG_BP:
                r.setdefault(op.mem.disp,set()).add(i.address)
    return r
a=offs(open(f'{d}/orig.bin','rb').read()); b=offs(open(f'{d}/seg.bin','rb').read())
fmt=lambda r:' '.join((f'-{-k:x}' if k<0 else f'+{k:x}')+f'({len(r[k])})' for k in sorted(r,reverse=True))
print('orig :',fmt(a)); print('built:',fmt(b))
for k in sorted(set(a)|set(b),reverse=True):
    if a.get(k)!=b.get(k): print(f'  {k:+x}: orig@{sorted(f"{x:x}" for x in a.get(k,[]))[:4]} built@{sorted(f"{x:x}" for x in b.get(k,[]))[:4]}')
