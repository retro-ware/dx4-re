"""Collect DS-relative memory references per code segment of a TP7 EXE.  usage: dsrefs.py EXE"""
import sys, collections
sys.path.insert(0, __file__.rsplit('/', 1)[0] + '/tpdec')
from model import Model, CS
from capstone import x86

def refs(M):
    out = collections.defaultdict(dict)   # ofs -> {seg: maxsize}
    for key in sorted(M.procs):
        p = M.procs[key]
        ins_l = M.disasm(p)
        for j, ins in enumerate(ins_l):
            # address-of a global: push ds next to mov reg,imm / push imm
            if ins.mnemonic == 'push' and ins.op_str == 'ds':
                for k in (j - 1, j + 1):
                    if 0 <= k < len(ins_l):
                        q = ins_l[k]
                        if (q.mnemonic == 'mov' and q.operands[1].type == x86.X86_OP_IMM) or (q.mnemonic == 'push' and q.operands[0].type == x86.X86_OP_IMM):
                            o = q.operands[-1].imm & 0xffff
                            out[o][key[0]] = max(out[o].get(key[0], 0), 0)
            for op in ins.operands:
                if op.type == x86.X86_OP_MEM and op.mem.base == 0 and op.mem.index == 0 and op.mem.segment in (0, x86.X86_REG_DS):
                    o = op.mem.disp & 0xffff
                    out[o][key[0]] = max(out[o].get(key[0], 0), op.size)
            # push ds; mov di, imm  -> address-of global
            if ins.mnemonic == 'mov' and len(ins.operands) == 2 and ins.operands[1].type == x86.X86_OP_IMM:
                pass
    return out

if __name__ == '__main__':
    M = Model(sys.argv[1])
    r = refs(M)
    for o in sorted(r):
        print(f'{o:04x} ' + ' '.join(f'{s:04x}:{z}' for s, z in sorted(r[o].items())))
