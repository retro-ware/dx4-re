"""mapline.py CHKDIR UNITNAME OFFHEX...: source line for code offsets, via the T.MAP line-number table"""
import sys,re
d,unit=sys.argv[1],sys.argv[2]
mp=open(f'{d}/T.MAP').read()
sec=re.search(r'Line numbers for '+unit+r'\(.*?\n(.*?)(?:\n\n|\Z)',mp,re.S|re.I)[1]
pairs=sorted((int(o,16),int(l)) for l,s,o in re.findall(r'(\d+) ([0-9A-F]{4}):([0-9A-F]{4})',sec))
for a in sys.argv[3:]:
    o=int(a,16); best=[p for p in pairs if p[0]<=o][-1]
    print(f'{o:x} -> line {best[1]} (at {best[0]:x})')
