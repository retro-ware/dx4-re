"""Lift TP7 machine code of one procedure to flat Pascal-like statements (with labels/gotos).

The lifter is a symbolic evaluator over the 8086 register file.  TP7 never keeps values in registers
across statements, so a statement ends at every store, call-as-statement, or jump.
"""
import struct
from capstone import x86
from model import CS

R = x86  # shorthand


class E:
    """Expression: text + size in bytes (1,2,4,6,256 for strings) + signedness + kind."""
    __slots__ = ('t', 'size', 'signed', 'kind', 'prec')

    def __init__(self, t, size=2, signed=False, kind='val', prec=9):
        self.t, self.size, self.signed, self.kind, self.prec = t, size, signed, kind, prec

    def __repr__(self):
        return self.t

    def p(self, prec):
        """Text, parenthesized if this binds weaker than prec."""
        return self.t if self.prec >= prec else f'({self.t})'


def binop(a, op, b, prec, size=None, signed=None):
    return E(f'{a.p(prec)} {op} {b.p(prec + 1)}', size or max(a.size, b.size),
             a.signed if signed is None else signed, prec=prec)


CONDS = {  # jcc after cmp a,b  -> Pascal relation (taken)
    'je': '=', 'jne': '<>', 'jl': '<', 'jge': '>=', 'jg': '>', 'jle': '<=',
    'jb': '<', 'jae': '>=', 'ja': '>', 'jbe': '<=',
}
SIGNED_J = {'jl', 'jge', 'jg', 'jle'}


class Lifter:
    def __init__(self, model, proc, names):
        self.M, self.p, self.N = model, proc, names
        self.out = []            # list of (addr, text)
        self.labels = set()
        self.reset()

    # ------------------------------------------------------------------ state
    def reset(self):
        self.reg = {}            # 'ax','dx','cx','bx','si','di','es' -> E ; 8-bit via ax split
        self.stack = []          # pushed expressions
        self.flags = None        # (a, b, kind) from last cmp/test/or
        self.esdi = None         # pointer expression in es:di (from les di,...)
        self.dssi = None

    def emit(self, addr, text):
        self.out.append((addr, text))

    # ------------------------------------------------------------- naming
    def bpname(self, disp, size):
        p = self.p
        if disp > 0:
            return self.N.param(p, disp, size)
        return self.N.local(p, disp, size)

    def glob(self, disp, size):
        return self.N.glob(disp, size)

    def memexpr(self, ins, op, size):
        """Expression for a memory operand."""
        m = op.mem
        base = ins.reg_name(m.base) if m.base else None
        idx = ins.reg_name(m.index) if m.index else None
        seg = ins.reg_name(m.segment) if m.segment else None
        d = m.disp & 0xffff
        sd = m.disp if m.disp < 0x8000 else m.disp - 0x10000
        if base == 'bp' and not idx:
            return E(self.bpname(sd, size), size)
        if base is None and idx is None and seg in (None, 'ds'):
            return E(self.glob(d, size), size)
        if seg == 'es' and base == 'di' and not idx and self.esdi is not None:
            return E(self.N.field(self.esdi, d, size), size)
        if base == 'di' and not idx and seg in (None, 'ds') and 'di' in self.reg:
            return E(self.N.index(self.glob(d, size), self.reg['di'], size), size)
        if base == 'bx' and not idx and seg in (None, 'ds') and 'bx' in self.reg:
            return E(self.N.index(self.glob(d, size), self.reg['bx'], size), size)
        if base == 'bp' and idx == 'di' and 'di' in self.reg:
            return E(self.N.index(self.bpname(sd, size), self.reg['di'], size), size)
        if base == 'bp' and idx == 'si' and 'si' in self.reg:
            return E(self.N.index(self.bpname(sd, size), self.reg['si'], size), size)
        return E(f'MEM[{ins.op_str}]', size)

    def opexpr(self, ins, op, size=None):
        if op.type == R.X86_OP_IMM:
            v = op.imm & 0xffff
            return E(str(v) if v < 256 else f'${v:X}', size or op.size, kind='const')
        if op.type == R.X86_OP_REG:
            return self.getreg(ins.reg_name(op.reg))
        return self.memexpr(ins, op, op.size)

    # ---------------------------------------------------------- registers
    def getreg(self, r):
        if r in ('al', 'cl', 'dl', 'bl'):
            full = r[0] + 'x'
            e = self.reg.get(full)
            if e is None:
                return E(f'?{r}', 1)
            return E(e.t, 1, e.signed, e.kind, e.prec) if e.size == 1 else E(f'Lo({e.t})', 1)
        if r == 'ah' and 'ax' in self.reg and self.reg['ax'].size == 4:
            return E(f'?ah', 1)
        e = self.reg.get(r)
        if e is None:
            if r == 'dx' and 'dxax' in self.reg:
                return E(f'HiWord({self.reg["dxax"].t})', 2)
            return E(f'?{r}', 2)
        return e

    def setreg(self, r, e):
        if r in ('al', 'cl', 'dl', 'bl'):
            self.reg[r[0] + 'x'] = E(e.t, 1, e.signed, e.kind, e.prec)
        else:
            self.reg[r] = e

    # ------------------------------------------------------------- lifting
    def run(self):
        ins = self.p.ins
        targets = set()
        for i in ins:
            if i.group(R.X86_GRP_JUMP) and i.operands and i.operands[0].type == R.X86_OP_IMM:
                targets.add(i.operands[0].imm)
        self.labels = targets
        k = 0
        n = len(ins)
        while k < n:
            i = ins[k]
            if i.address in targets:
                self.flush(i.address)
                self.emit(i.address, f'L{i.address:04X}:')
                self.reset()
            k = self.step(ins, k)
        return self.out

    def flush(self, addr):
        if self.stack:
            self.emit(addr, f'{{ stack: {self.stack} }}')
        self.stack = []

    def step(self, ins, k):
        i = ins[k]
        mn, ops = i.mnemonic, i.operands
        a = i.address
        h = getattr(self, 'i_' + mn, None)
        if h is None:
            self.emit(a, f'asm {mn} {i.op_str} end;')
            self.reset()
            return k + 1
        r = h(ins, k, i, ops)
        return k + 1 if r is None else r

    # --- data movement
    def i_mov(self, ins, k, i, ops):
        d, s = ops
        if d.type == R.X86_OP_REG:
            rn = i.reg_name(d.reg)
            if rn in ('es', 'ds', 'ss'):
                if rn == 'ds' and s.type == R.X86_OP_REG and i.reg_name(s.reg) == 'bx':
                    return
                return
            if rn == 'ah' and s.type == R.X86_OP_IMM and s.imm == 0:
                return
            if s.type == R.X86_OP_REG and i.reg_name(s.reg) in ('ds', 'ss', 'cs'):
                self.setreg(rn, E(i.reg_name(s.reg).upper() + 'Seg', 2))
                return
            e = self.opexpr(i, s)
            if rn == 'dx' and s.type == R.X86_OP_MEM and 'ax' in self.reg and self.reg['ax'].size == 2:
                # mov ax,[x]; mov dx,[x+2] -> longint / pointer load
                lo = self.reg['ax']
                self.reg['dxax'] = E(lo.t, 4, lo.signed)
            self.setreg(rn, e)
            return
        # store to memory
        dst = self.memexpr(i, d, d.size)
        if s.type == R.X86_OP_IMM:
            v = s.imm & (0xff if d.size == 1 else 0xffff)
            self.emit(i.address, f'{dst.t} := {self.N.const(v, d.size, dst.t)};')
            return
        rn = i.reg_name(s.reg)
        if rn == 'dx' and self.out and self.out[-1][1].startswith(self.N.hi_of(dst.t)):
            pass
        src = self.getreg(rn)
        if rn == 'dx' and 'dxax' in self.reg:
            # second half of a longint store: merge with preceding "x := ax" store
            last = self.out[-1] if self.out else None
            if last and last[1].endswith(f':= {self.reg["dxax"].t};'):
                lhs = last[1].split(' := ')[0]
                self.out[-1] = (last[0], f'{lhs} := {self.reg["dxax"].t};')
                return
        self.emit(i.address, f'{dst.t} := {src.t};')

    def i_les(self, ins, k, i, ops):
        src = self.memexpr(i, ops[1], 4)
        if ops[1].mem.segment and i.reg_name(ops[1].mem.segment) == 'es' and self.esdi is not None:
            self.esdi = E(self.N.field(self.esdi, ops[1].mem.disp, 4), 4)
        else:
            self.esdi = E(src.t, 4)
        self.reg['di'] = self.esdi
    i_lds = i_les

    def i_lea(self, ins, k, i, ops):
        src = self.memexpr(i, ops[1], 0)
        self.setreg(i.reg_name(ops[0].reg), E(f'@{src.t}', 2, kind='addr'))

    def i_push(self, ins, k, i, ops):
        o = ops[0]
        if o.type == R.X86_OP_REG:
            rn = i.reg_name(o.reg)
            if rn in ('ss', 'ds', 'cs', 'es'):
                self.stack.append(E(rn, 2, kind='segreg'))
                return
            self.stack.append(self.getreg(rn))
        else:
            self.stack.append(self.opexpr(i, o, 2))

    def i_pop(self, ins, k, i, ops):
        if self.stack:
            v = self.stack.pop()
            self.setreg(i.reg_name(ops[0].reg), v)

    # --- arithmetic (expression building)
    def _arith(self, i, ops, op, prec):
        d, s = ops
        if d.type == R.X86_OP_REG:
            rn = i.reg_name(d.reg)
            a = self.getreg(rn)
            b = self.opexpr(i, s, d.size)
            self.setreg(rn, binop(a, op, b, prec, size=a.size))
            self.flags = ('expr', self.getreg(rn))
        else:
            dst = self.memexpr(i, d, d.size)
            b = self.opexpr(i, s, d.size)
            if op == '+' and b.t == '1':
                self.emit(i.address, f'Inc({dst.t});')
            elif op == '-' and b.t == '1':
                self.emit(i.address, f'Dec({dst.t});')
            elif op in '+-':
                self.emit(i.address, f'{"Inc" if op == "+" else "Dec"}({dst.t}, {b.t});')
            else:
                self.emit(i.address, f'{dst.t} := {binop(dst, op, b, prec).t};')

    def i_add(self, ins, k, i, ops):
        self._arith(i, ops, '+', 4)

    def i_sub(self, ins, k, i, ops):
        self._arith(i, ops, '-', 4)

    def i_and(self, ins, k, i, ops):
        self._arith(i, ops, 'and', 5)

    def i_or(self, ins, k, i, ops):
        d, s = ops
        if d.type == R.X86_OP_REG and s.type == R.X86_OP_REG and d.reg == s.reg:
            self.flags = ('test', self.getreg(i.reg_name(d.reg)))
            return
        self._arith(i, ops, 'or', 4)

    def i_xor(self, ins, k, i, ops):
        d, s = ops
        if d.type == R.X86_OP_REG and s.type == R.X86_OP_REG and d.reg == s.reg:
            rn = i.reg_name(d.reg)
            if rn == 'ah':
                a = self.reg.get('ax')
                if a is not None:
                    self.reg['ax'] = E(a.t, 2, False, a.kind, a.prec)
                return
            if rn == 'ch':
                return
            self.setreg(rn, E('0', 2, kind='const'))
            return
        self._arith(i, ops, 'xor', 4)

    def i_inc(self, ins, k, i, ops):
        d = ops[0]
        if d.type == R.X86_OP_REG:
            rn = i.reg_name(d.reg)
            self.setreg(rn, binop(self.getreg(rn), '+', E('1', kind='const'), 4))
        else:
            self.emit(i.address, f'Inc({self.memexpr(i, d, d.size).t});')

    def i_dec(self, ins, k, i, ops):
        d = ops[0]
        if d.type == R.X86_OP_REG:
            rn = i.reg_name(d.reg)
            self.setreg(rn, binop(self.getreg(rn), '-', E('1', kind='const'), 4))
        else:
            self.emit(i.address, f'Dec({self.memexpr(i, d, d.size).t});')

    def i_cbw(self, ins, k, i, ops):
        a = self.reg.get('ax')
        if a is not None:
            self.reg['ax'] = E(a.t, 2, True, a.kind, a.prec)

    def i_cwd(self, ins, k, i, ops):
        a = self.reg.get('ax')
        if a is not None:
            self.reg['dxax'] = E(a.t, 4, True, a.kind, a.prec)

    def i_neg(self, ins, k, i, ops):
        rn = i.reg_name(ops[0].reg)
        self.setreg(rn, E(f'-{self.getreg(rn).p(8)}', 2, True, prec=8))

    def i_not(self, ins, k, i, ops):
        rn = i.reg_name(ops[0].reg)
        self.setreg(rn, E(f'not {self.getreg(rn).p(8)}', 2, prec=8))

    def i_shl(self, ins, k, i, ops):
        self._arith(i, ops, 'shl', 5)

    def i_shr(self, ins, k, i, ops):
        self._arith(i, ops, 'shr', 5)

    def i_imul(self, ins, k, i, ops):
        if len(ops) == 1:
            a = self.getreg('ax')
            b = self.opexpr(i, ops[0])
            self.reg['ax'] = binop(a, '*', b, 5)
            self.reg['dxax'] = E(self.reg['ax'].t, 4, True)
        else:
            self._arith(i, ops[:2], '*', 5)
    i_mul = i_imul

    def i_div(self, ins, k, i, ops):
        a = self.getreg('ax')
        b = self.opexpr(i, ops[0])
        self.reg['dx'] = binop(a, 'mod', b, 5)
        self.reg['ax'] = binop(a, 'div', b, 5)
    i_idiv = i_div

    def i_xchg(self, ins, k, i, ops):
        r1, r2 = i.reg_name(ops[0].reg), i.reg_name(ops[1].reg)
        a, b = self.getreg(r1), self.getreg(r2)
        self.setreg(r1, b)
        self.setreg(r2, a)

    # --- compare / jumps
    def i_cmp(self, ins, k, i, ops):
        a = self.opexpr(i, ops[0])
        b = self.opexpr(i, ops[1], ops[0].size)
        self.flags = ('cmp', a, b)

    def i_test(self, ins, k, i, ops):
        a = self.opexpr(i, ops[0])
        b = self.opexpr(i, ops[1])
        self.flags = ('and', a, b)

    def cond(self, mn):
        f = self.flags
        if f is None:
            return f'?{mn}'
        if f[0] == 'cmp':
            rel = CONDS.get(mn)
            if rel is None:
                return f'?{mn}({f[1].t},{f[2].t})'
            return f'{f[1].p(4)} {rel} {f[2].p(4)}'
        if f[0] in ('test', 'expr'):
            e = f[1]
            if mn == 'je':
                return f'{e.p(4)} = 0'
            if mn == 'jne':
                return f'{e.p(4)} <> 0'
            if mn == 'jl':
                return f'{e.p(4)} < 0'
            if mn == 'jge':
                return f'{e.p(4)} >= 0'
            return f'?{mn}({e.t})'
        if f[0] == 'and':
            if mn == 'je':
                return f'{f[1].p(5)} and {f[2].p(5)} = 0'
            return f'{f[1].p(5)} and {f[2].p(5)} <> 0'
        if f[0] == 'call':
            return f'{f[1].t}' if mn == 'jne' else f'not {f[1].t}'
        return f'?{mn}'

    def jcc(self, ins, k, i, ops):
        t = ops[0].imm
        c = self.cond(i.mnemonic)
        self.flush(i.address)
        self.emit(i.address, f'if {c} then goto L{t:04X};')
        # register state survives a not-taken jcc (TP materializes booleans like: mov al,0; jnz; inc ax)
        return None

    def i_jmp(self, ins, k, i, ops):
        if ops[0].type == R.X86_OP_IMM:
            self.flush(i.address)
            self.emit(i.address, f'goto L{ops[0].imm:04X};')
        else:
            self.emit(i.address, f'asm jmp {i.op_str} end;')
        self.reset()

    # --- calls
    def i_lcall(self, ins, k, i, ops):
        b = i.bytes
        if b[0] == 0x9a:
            off, seg = struct.unpack_from('<HH', b, 1)
            if seg == self.M.sysseg:
                return self.rtl_call(i, off)
            self.proc_call(i, (seg, off), far=True)
            return
        self.emit(i.address, f'asm call far {i.op_str} end;')
        self.reset()

    def i_call(self, ins, k, i, ops):
        if ops[0].type == R.X86_OP_IMM:
            pushcs = self.stack and self.stack[-1].kind == 'segreg' and self.stack[-1].t == 'cs'
            if pushcs:
                self.stack.pop()
            self.proc_call(i, (self.p.seg, ops[0].imm), far=pushcs)
            return
        self.emit(i.address, f'asm call {i.op_str} end;')
        self.reset()

    def pop_ptr(self):
        """Pop a far pointer pushed as seg, off.  Returns expression for the pointed-to object."""
        off = self.stack.pop() if self.stack else E('?')
        seg = self.stack.pop() if self.stack else E('?')
        return self.N.ptrarg(seg, off)

    def proc_call(self, i, target, far):
        q = self.N.proc_info(target)
        args = []
        n = q.argsize if q else 0
        # pop arguments: we don't know the parameter list yet; pop words until argsize consumed
        words = []
        while n > 0 and self.stack:
            e = self.stack.pop()
            words.insert(0, e)
            n -= 2
        args = self.N.group_args(words)
        name = self.N.procname(target)
        call = f'{name}({", ".join(a.t for a in args)})' if args else name
        self.reset_regs_after_call()
        if q and q.is_func:
            self.reg['ax'] = E(call, 2)
            self.reg['dxax'] = E(call, 4)
            self.flags = ('call', E(call))
        else:
            self.emit(i.address, call + ';')

    def reset_regs_after_call(self):
        self.reg = {}
        self.esdi = None

    def rtl_call(self, i, off):
        name = self.M.rtl.get(off, f'RTL_{off:04X}')
        h = getattr(self, 'rtl_' + name, None)
        if h:
            return h(i)
        self.emit(i.address, f'{{RTL}} {name}({", ".join(e.t for e in self.stack)});')
        self.stack = []
        self.reset_regs_after_call()

    # string helpers: TP builds string expressions in a temp: StrLoad(tmp, src) ; StrConcat(src) ...; StrStore(dst, max)
    def rtl_StrLoad(self, i):
        src = self.pop_ptr()
        tmp = self.pop_ptr()
        self.stack.append(E(src.t, 256, kind='str'))
        self.stack.append(E('', 0, kind='strtmp'))

    def _top_str(self):
        # stack: ..., strexpr, marker
        if len(self.stack) >= 2 and self.stack[-1].kind == 'strtmp':
            self.stack.pop()
            return self.stack.pop()
        if len(self.stack) >= 2:
            return self.pop_ptr()
        return E('?str', 256)

    def rtl_StrConcat(self, i):
        src = self.pop_ptr()
        cur = self._top_str()
        self.stack.append(E(f'{cur.t} + {src.t}', 256, kind='str', prec=4))
        self.stack.append(E('', 0, kind='strtmp'))

    def rtl_StrStore(self, i):
        mx = self.stack.pop() if self.stack else E('?')
        dst = self.pop_ptr()
        src = self._top_str() if self.stack and self.stack[-1].kind == 'strtmp' else self.pop_ptr()
        self.emit(i.address, f'{dst.t} := {src.t};')

    def rtl_StrCompare(self, i):
        b = self._top_str() if self.stack and self.stack[-1].kind == 'strtmp' else self.pop_ptr()
        a = self._top_str() if self.stack and self.stack[-1].kind == 'strtmp' else self.pop_ptr()
        self.flags = ('cmp', a, b)

    def rtl_StrChar(self, i):
        c = self.stack.pop() if self.stack else E('?')
        tmp = self.pop_ptr()
        self.stack.append(E(c.t, 256, kind='str'))
        self.stack.append(E('', 0, kind='strtmp'))

    def rtl_StrCopy(self, i):
        cnt = self.stack.pop()
        idx = self.stack.pop()
        s = self.pop_ptr()
        tmp = self.pop_ptr()
        self.stack.append(E(f'Copy({s.t}, {idx.t}, {cnt.t})', 256, kind='str'))
        self.stack.append(E('', 0, kind='strtmp'))

    def rtl_StrPos(self, i):
        s = self._top_str() if self.stack and self.stack[-1].kind == 'strtmp' else self.pop_ptr()
        sub = self._top_str() if self.stack and self.stack[-1].kind == 'strtmp' else self.pop_ptr()
        self.reg['ax'] = E(f'Pos({sub.t}, {s.t})', 2)
        self.flags = ('expr', self.reg['ax'])

    def rtl_Move(self, i):
        n = self.stack.pop()
        d = self.pop_ptr()
        s = self.pop_ptr()
        self.emit(i.address, f'Move({s.t}, {d.t}, {n.t});')

    def rtl_FillChar(self, i):
        v = self.stack.pop()
        n = self.stack.pop()
        d = self.pop_ptr()
        self.emit(i.address, f'FillChar({d.t}, {n.t}, {v.t});')

    def rtl_GetMem(self, i):
        n = self.stack.pop() if self.stack else E('?')
        self.reg['dxax'] = E(f'GetMem({n.t})', 4, kind='getmem')
        self.reg['ax'] = self.reg['dxax']

    def rtl_FreeMem(self, i):
        n = self.stack.pop() if self.stack else E('?')
        p = self.pop_ptr()
        self.emit(i.address, f'FreeMem({p.t}, {n.t});')

    def rtl_Halt(self, i):
        self.emit(i.address, f'Halt({self.getreg("ax").t});')

    # --- string ops (inline sequences like value-param copies)
    def i_cld(self, ins, k, i, ops):
        return

    def i_lodsb(self, ins, k, i, ops):
        return

    def i_stosb(self, ins, k, i, ops):
        return

    def i_movsb(self, ins, k, i, ops):
        return

    def i_leave(self, ins, k, i, ops):
        return

    def i_enter(self, ins, k, i, ops):
        return

    def i_retf(self, ins, k, i, ops):
        self.emit(i.address, '{exit}')
    i_ret = i_retf


for _j in ('je', 'jne', 'jl', 'jge', 'jg', 'jle', 'jb', 'jae', 'ja', 'jbe', 'js', 'jns', 'jcxz'):
    setattr(Lifter, 'i_' + _j, Lifter.jcc)
