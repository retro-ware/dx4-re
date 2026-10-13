"""Minimal MZ helpers: header, image, relocations."""
import struct, sys

class MZ:
    def __init__(self, path):
        self.data = d = open(path, 'rb').read()
        (self.sig, self.cblp, self.cp, self.crlc, self.cparhdr, self.minalloc, self.maxalloc,
         self.ss, self.sp, self.csum, self.ip, self.cs, self.lfarlc, self.ovno) = struct.unpack_from('<14H', d, 0)
        size = self.cp * 512 - (512 - self.cblp if self.cblp else 0)
        self.hdr = self.cparhdr * 16
        self.image = d[self.hdr:size]
        self.overlay = d[size:]
        self.relocs = [struct.unpack_from('<HH', d, self.lfarlc + 4 * i) for i in range(self.crlc)]

    def reloc_offsets(self):
        return sorted(seg * 16 + off for off, seg in self.relocs)

    def masked(self):
        b = bytearray(self.image)
        for o in self.reloc_offsets():
            b[o:o + 2] = b'\0\0'
        return bytes(b)

if __name__ == '__main__':
    for p in sys.argv[1:]:
        m = MZ(p)
        print(f'{p}: image={len(m.image):#x} relocs={m.crlc} cs:ip={m.cs:04x}:{m.ip:04x} ss:sp={m.ss:04x}:{m.sp:04x} '
              f'min={m.minalloc:#x} max={m.maxalloc:#x} ovl={len(m.overlay):#x}')
