import sys,capstone
md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_16)
d=sys.argv[1]; rngs=sys.argv[2:]
a=open(f'{d}/orig.bin','rb').read(); b=open(f'{d}/seg.bin','rb').read()
for r in rngs:
    s,e=(int(x,16) for x in r.split('-'))
    for n,buf in (('orig',a),('built',b)):
        print(n)
        for i in md.disasm(buf[s:e],s): print(f"  {i.address:04x}: {i.bytes.hex():14} {i.mnemonic} {i.op_str}")
