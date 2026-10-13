"""Program model for a TP7 EXE: segments, units, procedures, DS layout, relocations, RTL names."""
import sys, struct, json, os
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from mz import MZ
from tpsegs import segments
import rtlsig
import capstone
from capstone import x86

CS = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_16)
CS.detail = True


class Proc:
    def __init__(self, seg, off, end):
        self.seg, self.off, self.end = seg, off, end
        self.name = f'P{seg:04X}_{off:04X}'
        self.far = None          # True: retf, False: ret
        self.argsize = 0         # bytes popped by ret N
        self.frame = 0           # local frame size (enter N / sub sp,N)
        self.nested = False      # TP nested procedure (gets parent's BP pushed)
        self.ins = []
        self.is_func, self.ressize, self.resslot = False, 0, None

    def __repr__(self):
        return f'<{self.name} {"far" if self.far else "near"} args={self.argsize} frame={self.frame}>'


class Model:
    def __init__(self, path, ovl=False):
        self.m = m = MZ(path)
        self.img = m.image
        self.relocs = set(m.reloc_offsets())
        self.segs, _ = segments(m)
        if 0 not in self.segs:
            self.segs = [0] + self.segs
        self.sysseg, rtl = rtlsig.name(path)
        self.rtl = {o: n[0] for o, n in rtl.items()}
        # DS = value loaded by System init: "mov ax,DATA" at System:0001 (reloc)
        self.ds = int.from_bytes(self.img[self.sysseg*16+1:self.sysseg*16+3], 'little')
        self.codesegs = [s for s in self.segs if s < self.ds]
        ends = self.codesegs[1:] + [self.ds]
        self.segend = dict(zip(self.codesegs, ends))
        self.find_procs()

    def seg_bytes(self, s):
        return self.img[s*16:self.segend[s]*16]

    def reloc_at(self, lin):
        return lin in self.relocs

    def find_procs(self):
        import tpprocs
        starts = {}
        for s, o in tpprocs.procs(self.m):
            if s in self.segend and s != self.sysseg:
                starts.setdefault(s, set()).add(o)
        # also near-call targets inside each segment
        for s in list(starts):
            b = self.seg_bytes(s)
            for i in range(len(b) - 3):
                if b[i] == 0xe8 and i >= 1 and b[i-1] == 0x0e:     # push cs; call near
                    t = (i + 3 + struct.unpack_from('<h', b, i+1)[0]) & 0xffff
                    if t < len(b):
                        starts[s].add(t)
        self.procs = {}
        for s, offs in starts.items():
            offs = sorted(offs)
            for o, n in zip(offs, offs[1:] + [len(self.seg_bytes(s))]):
                p = Proc(s, o, n)
                self.procs[(s, o)] = p

    def disasm(self, p):
        b = self.seg_bytes(p.seg)
        out = []
        for ins in CS.disasm(bytes(b[p.off:p.end]), p.off):
            out.append(ins)
            if ins.mnemonic in ('ret', 'retf') :
                p.far = ins.mnemonic == 'retf'
                p.argsize = ins.operands[0].imm if ins.operands else 0
                p.end = ins.address + ins.size
                break
        p.ins = out
        # function result: TP loads it from the result slot right before the epilogue
        p.is_func, p.ressize, p.resslot = False, 0, None
        tail = [i for i in out[-6:] if i.mnemonic not in ('leave', 'ret', 'retf', 'pop')]
        if out and out[-2:] and len(out) >= 3:
            j = len(out) - 1
            while j > 0 and out[j].mnemonic in ('leave', 'ret', 'retf', 'pop') or (j > 0 and out[j].mnemonic == 'mov' and out[j].op_str == 'sp, bp'):
                j -= 1
            loads = []
            while j >= 0 and out[j].mnemonic == 'mov' and out[j].op_str.split(',')[0] in ('al', 'ax', 'dx') and '[bp - ' in out[j].op_str:
                loads.insert(0, out[j]); j -= 1
            if loads:
                p.is_func = True
                regs = [l.op_str.split(',')[0] for l in loads]
                p.ressize = 1 if regs == ['al'] else 4 if 'dx' in regs else 2
                p.resslot = min(l.operands[1].mem.disp for l in loads)
        return out
