"""Decompile procedures of a TP7 EXE segment to flat Pascal-like text.  usage: dec.py EXE SEG"""
import sys
from model import Model
from names import Names
from lift import Lifter


def prologue(p):
    """Skip TP prologue; record frame size.  Returns index of first body instruction."""
    ins = p.ins
    k = 0
    if ins and ins[0].mnemonic == 'enter':
        p.frame = ins[0].operands[0].imm
        k = 1
    elif len(ins) > 1 and ins[0].mnemonic == 'push' and ins[0].op_str == 'bp' and ins[1].mnemonic == 'mov':
        k = 2
        if len(ins) > 2 and ins[2].mnemonic == 'sub' and ins[2].op_str.startswith('sp'):
            p.frame = ins[2].operands[1].imm
            k = 3
    return k


def main():
    M = Model(sys.argv[1])
    seg = int(sys.argv[2], 16)
    N = Names(M)
    for key in sorted(M.procs):
        M.disasm(M.procs[key])
    for key in sorted(k for k in M.procs if k[0] == seg):
        p = M.procs[key]
        N.cur = p
        k = prologue(p)
        body = p.ins[k:]
        p.ins = body
        L = Lifter(M, p, N)
        out = L.run()
        print(f'\nprocedure {p.name}; {{ {"far" if p.far else "near"} args={p.argsize} frame={p.frame} }}')
        for a, t in out:
            print(f'  {t}' if not t.endswith(':') else t)


if __name__ == '__main__':
    main()
