# Generate a deterministic 256x256 flat PNG without external art tooling.
import struct,zlib
w=h=256
rows=[]
for y in range(h):
    row=bytearray([0])
    for x in range(w):
        edge=min(x,y,w-1-x,h-1-y)
        if edge<8: c=(18,18,24,255)
        elif ((x-128)**2+(y-128)**2)<86**2: c=(106,72,196,255)
        else: c=(39,31,70,255)
        row.extend(c)
    rows.append(bytes(row))
def chunk(t,d):
    return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows),9))+chunk(b'IEND',b'')
open('pak/art/MKXPZ.png','wb').write(png)
