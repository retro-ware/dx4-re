"""Naming/typing context shared by the lifter: globals, params, locals, fields, procs."""
from lift import E


def tyname(size, signed=False):
    return {1: 'ShortInt' if signed else 'Byte', 2: 'Integer' if signed else 'Word', 4: 'LongInt' if signed else 'Pointer',
            6: 'Real'}.get(size, f'array[0..{size - 1}] of Byte')


class Names:
    def __init__(self, model):
        self.M = model
        self.globals = {}        # ofs -> {size}
        self.params = {}         # (proc key) -> {disp: size}
        self.locals = {}
        self.info = {}           # (seg, off) -> Proc

    # -------- variables
    def glob(self, ofs, size):
        g = self.globals.setdefault(ofs, {'size': 0})
        g['size'] = max(g['size'], size)
        return f'g{ofs:04X}'

    def param(self, p, disp, size):
        d = self.params.setdefault((p.seg, p.off), {})
        d[disp] = max(d.get(disp, 0), size)
        return f'a{disp:X}'

    def local(self, p, disp, size):
        d = self.locals.setdefault((p.seg, p.off), {})
        d[disp] = max(d.get(disp, 0), size)
        return f'v{-disp:X}'

    def field(self, ptr, off, size):
        off &= 0xffff
        return f'{ptr.t}^.f{off:X}' if off else f'{ptr.t}^.f0'

    def index(self, base, idx, size):
        return f'{base}[{idx.t}]'

    def const(self, v, size, dst=None):
        return str(v) if v < 256 else f'${v:X}'

    def hi_of(self, t):
        return t

    def ptrarg(self, seg, off):
        if off.kind == 'addr':
            return E(off.t[1:], 256)
        if seg.kind == 'segreg' and seg.t == 'cs' and off.kind == 'const':
            return E(self.literal(int(off.t.lstrip('$'), 16 if off.t.startswith('$') else 10)), 256, kind='lit')
        if seg.kind == 'segreg' and seg.t == 'ds' and off.kind == 'const':
            v = int(off.t.lstrip('$'), 16 if off.t.startswith('$') else 10)
            return E(self.glob(v, 1), 256)
        if seg.kind == 'segreg' and seg.t == 'es':
            return E(f'{off.t}^', 256)
        return E(f'Ptr({seg.t}, {off.t})^', 256)

    def literal(self, off):
        b = self.M.seg_bytes(self.cur.seg)
        n = b[off]
        s = b[off + 1:off + 1 + n]
        return pas_string(s)

    # -------- procedures
    def proc_info(self, target):
        return self.M.procs.get(target)

    def procname(self, target):
        p = self.M.procs.get(target)
        return p.name if p else f'P{target[0]:04X}_{target[1]:04X}'

    def group_args(self, words):
        """Combine pushed words into arguments: (seg, off) pairs become var/pointer arguments."""
        out = []
        i = 0
        while i < len(words):
            w = words[i]
            if w.kind == 'segreg' and i + 1 < len(words):
                out.append(self.ptrarg(w, words[i + 1]))
                i += 2
                continue
            out.append(w)
            i += 1
        return out


def pas_string(s):
    out, inq = [], False
    for c in s:
        if 32 <= c < 127 and c != 39:
            if not inq:
                out.append("'")
                inq = True
            out.append(chr(c))
        elif c == 39:
            if not inq:
                out.append("'")
                inq = True
            out.append("''")
        else:
            if inq:
                out.append("'")
                inq = False
            out.append(f'#{c}' if c < 128 else f'#${c:02X}')
    if inq:
        out.append("'")
    return ''.join(out) or "''"
