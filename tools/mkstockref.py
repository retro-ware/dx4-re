"""Generate a reference program that takes the address of every interface proc/method of stock units."""
import re, sys
RTL = 'toolchain/bp701/rtl/'
UNITS = ['Crt', 'Dos', 'Printer', 'Overlay', 'Objects', 'Drivers', 'Memory', 'Views', 'Menus', 'Dialogs', 'App',
         'HistList', 'StdDlg', 'MsgBox', 'Editors', 'TextView', 'Outline', 'ColorSel', 'Validate']
skip = set(sys.argv[1:])
lines = []
for u in UNITS:
    src = open(RTL + u.lower() + '.pas', 'rb').read().decode('latin-1')
    src = re.sub(r'\{[^}]*\}|\(\*.*?\*\)', ' ', src, flags=re.S)
    intf = src[:re.search(r'\bimplementation\b', src, re.I).start()]
    intf = intf[re.search(r'\binterface\b', intf, re.I).end():]
    obj = None
    for st in re.split(r';', intf):
        st = st.strip()
        mo = re.match(r'(\w+)\s*=\s*object\b', st, re.I) or re.search(r'\b(\w+)\s*=\s*object\b', st, re.I)
        if mo:
            obj = mo.group(1)
            st = st[mo.end():].strip()
        if obj and re.match(r'end\b', st, re.I):
            obj = None
            continue
        mp = re.search(r'\b(procedure|function|constructor|destructor)\s+(\w+)', st, re.I)
        if not mp:
            continue
        name = mp.group(2)
        if obj:
            if re.search(r'\b\w+\s*=\s*(procedure|function)', st, re.I):
                continue
            q = f'{u}.{obj}.{name}'
        else:
            if re.search(r'=\s*(procedure|function)', st, re.I):
                continue
            q = f'{u}.{name}'
        if q in skip:
            continue
        lines.append(f'  P := @{q};')
seen, out = set(), []
for l in lines:
    if l not in seen:
        seen.add(l); out.append(l)
prog = ['{$F+,O-}', 'program StockRef;', 'uses ' + ',\r\n  '.join(UNITS) + ';', 'var P: Pointer;', 'begin'] + out + ['end.']
open('work/stock/STOCKREF.PAS', 'wb').write('\r\n'.join(prog).encode())
print(len(out), 'refs')
