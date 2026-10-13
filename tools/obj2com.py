"""Flatten a single-segment OMF .OBJ (TASM, org 100h) to a .COM image. usage: obj2com.py IN.OBJ OUT.COM
Segment-relative fixups need no patching: the segment base is 0 and TASM already stored the offsets."""
import sys, struct
d = open(sys.argv[1], 'rb').read()


def lidata(b, k):
    rep, nblk = struct.unpack_from('<HH', b, k); k += 4
    if nblk == 0:
        n = b[k]; out = b[k + 1:k + 1 + n]; k += 1 + n
    else:
        out = b''
        for _ in range(nblk):
            x, k = lidata(b, k); out += x
    return out * rep, k


img = bytearray(0x10000); hi = 0; i = 0
while i < len(d):
    t, n = d[i], struct.unpack_from('<H', d, i + 1)[0]
    body = d[i + 3:i + 3 + n - 1]
    if t == 0xA0:
        off = struct.unpack_from('<H', body, 1)[0]
        data = body[3:]
        img[off:off + len(data)] = data; hi = max(hi, off + len(data))
    elif t == 0xA2:
        off = struct.unpack_from('<H', body, 1)[0]
        data, _ = lidata(body, 3)
        img[off:off + len(data)] = data; hi = max(hi, off + len(data))
    i += 3 + n
open(sys.argv[2], 'wb').write(img[0x100:hi])
