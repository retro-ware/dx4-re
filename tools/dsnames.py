"""Map original DS offsets to global names: run tryunit on matched units, pair orig>built DS offsets from its 'addr map'
line and name the built offsets from the test link map (data publics). usage: dsnames.py ORIG.EXE OUT.json SEG:UNIT ...
Appends/updates OUT.json {orig_hex: name}. Uses TRYWORK=work/uDS."""
import sys, os, re, json, subprocess
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
orig, out = sys.argv[1], sys.argv[2]
names = json.load(open(out)) if os.path.exists(out) else {}
W = ROOT + '/work/uDS'
env = dict(os.environ, TRYWORK=W)
for su in sys.argv[3:]:
    seg, unit = su.split(':')
    r = subprocess.run([sys.executable, ROOT + '/tools/tryunit.py', orig, seg, f'{ROOT}/src/dxmain/{unit}.PAS'], env=env, capture_output=True, text=True)
    m = re.search(r'addr map: (.*)', r.stdout)
    if not m or not os.path.exists(W + '/T.MAP'):
        print(unit, 'no map', file=sys.stderr); continue
    mp = open(W + '/T.MAP').read()
    dseg = re.search(r'^\s*([0-9A-F]{5})H [0-9A-F]{5}H [0-9A-F]{5}H DATA\s+DATA', mp, re.M)
    para = int(dseg[1], 16) >> 4
    pubs = {int(off, 16): nm for sgn, off, nm in re.findall(r'^\s*([0-9A-F]{4}):([0-9A-F]{4})\s+(\S+)', mp, re.M) if int(sgn, 16) == para}
    n = 0
    for pair in m[1].split():
        o, b = pair.split('>')
        if '/' in b: continue
        o, b = int(o, 16), int(b, 16)
        # nearest public at or below the built offset
        cands = [k for k in pubs if k <= b]
        if not cands: continue
        k = max(cands); d = b - k
        key = f'{o:04x}'
        val = pubs[k] + (f'+{d:x}' if d else '')
        if key not in names: names[key] = val; n += 1
    print(unit, 'added', n, 'total', len(names))
    json.dump(names, open(out, 'w'), indent=0, sort_keys=True)
