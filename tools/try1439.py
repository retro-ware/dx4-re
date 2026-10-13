# Run tools/tryunit.py with segment 1439 (resident unit lumped into the 1435 overlay-stub segment) added to the segment table.
import sys, runpy, os
ROOT = '/Users/felix/Projects/x4'
sys.path[:0] = [ROOT + '/tools', ROOT + '/tools/tpdec']
import model
_init = model.Model.__init__
def init(self, *a, **k):
    _init(self, *a, **k)
    if 0x1435 in self.segend:
        self.segend[0x1439] = 0x1439 + 0x10d   # code ends at 0x10c2; the next overlay stub (int 3Fh) follows
model.Model.__init__ = init
sys.argv = [ROOT + '/tools/tryunit.py'] + sys.argv[1:]
runpy.run_path(ROOT + '/tools/tryunit.py', run_name='__main__')
