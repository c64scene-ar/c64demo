from wand.image import Image
from wand.drawing import Drawing
from wand.color import Color
import sys

mc = open("mc.c64", "rb").read()
mc_c = open("mc-c.c64", "rb").read()
mc_v = open("mc-v.c64", "rb").read()

mc_data = mc[2:]
mc_c_data = mc_c[2:]
mc_v_data = mc_v[2:]

print len(mc_data)
print len(mc_c_data)
print len(mc_v_data)

pepto = [(0x00,0x00,0x00),
         (0xFF,0xFF,0xFF),
         (0x68,0x37,0x2B),
         (0x70,0xA4,0xB2),
         (0x6F,0x3D,0x86),
         (0x58,0x8D,0x43),
         (0x35,0x28,0x79),
         (0xB8,0xC7,0x6F),
         (0x6F,0x4F,0x25),
         (0x43,0x39,0x00),
         (0x9A,0x67,0x59),
         (0x44,0x44,0x44),
         (0x6C,0x6C,0x6C),
         (0x9A,0xD2,0x84),
         (0x6C,0x5E,0xB5),
         (0x95,0x95,0x95)]

img = Image(width=160, height=200, resolution=300)
drw = Drawing()
drw.stroke_width = 0
bgcolor = 0 

"""
(WxH)
Mc_data is a stream that describes a 40x25 cell multi color bitmap, as a matrix.
Each cell is 4x8 px.
The full stream is 8000 bytes long.
Mc_data has each cell as its lines in order.
Two contiguous cells:
00 01 02 03 | 32 33 34 35 |
04 05 06 07 | 36 37 38 39 |
...
28 29 30 31 | 60 61 62 63 |

Its corresponding stream: 
00, 01, 02, 03, 04, 05, ..., 30, 31, 32,


contains 8000 bytes.
Each byte represents one cell line
The full matrix is 40x25 cells
Each cell is 4x8 px because it is a multi color bitmap.
Instead of reading Mc_data and then calculating x and y 
coordinates to write to the JPG we read Mc_data "by line"
This means we will read one full line of the matrix each time, so we have to skip the

"""

coords = []
offs = []
lidx = {}
for f in xrange(0, 8000, 320):
    for off in range(8):
        for n in range(40):
            stream_off = 8*n + off + f
            offs.append(stream_off)
            b = ord(mc_data[stream_off])
            
            binbyt = bin(b)[2:].zfill(8)

            for j in xrange(0, len(binbyt), 2):
            
                code = binbyt[j:j+2]

                # Map to 160 x 200 matrix
                x = n * 4 + j / 2
                y = off + f / 40

                #print x,y

                coords.append((x, y))

                # Map to 40 x 25
                x_4025 = int(x / 4.0) 
                y_4025 = int(y / 8.0) 

                print x_4025, y_4025

                if not (x_4025, y_4025) in lidx.keys():
                    lidx[(x_4025, y_4025)] = 0
                lidx[(x_4025, y_4025)] += 1
                
                # Index in 40 x 25 array
                idx = y_4025 * 20 + x_4025


                print idx

                if code == "00":
                    color = bgcolor
                elif code == "01":
                    #print hex(ord(mc_v_data[idx]))
                    color = ord(mc_v_data[idx]) & 0x0f
                    #color = bgcolor
                elif code == "10":
                    #print hex(ord(mc_v_data[idx]))
                    color = ord(mc_v_data[idx]) >> 4
                    #color = bgcolor
                elif code == "11":
                    #print hex(ord(mc_c_data[idx]))
                    color = ord(mc_c_data[idx]) & 0x0f
                    #color = bgcolor

                color_t = pepto[color]
                color_s = "rgb(" + str(color_t[0]) +  "," + str(color_t[1]) + "," + str(color_t[2]) +  ")"

                drw.fill_color = Color(color_s)
                drw.stroke_line_cap = 'square'
                drw.point(x,y)

drw(img)
img.save(filename='test.jpg')

# No dupe coords
print "# coords written:", len(coords)
assert len(coords) == len(set(coords))

# No dupe offs
print "# offs read:", len(offs)
assert len(offs) == len(set(offs))

# Accesses to color/screen RAM
print "# accesses to color/screen RAM:", len(lidx)

# "40x25"
# 64 = 8x8
for x in lidx.values():
    assert x == 64

sys.exit(0)

for i in range(len(mc_data)): 
    binbyt =  bin(ord(mc_data[i]))[2:].zfill(8)
    for j in xrange(0, len(binbyt), 2):
        code = binbyt[j:j+2]

        # On a 160 x 200 matrix
        y =  (i * 4) / 160
        x = ((i * 4) % 160) + j / 2

        #print x, y

        # Map to 40 x 25
        x_4025 = int(x / 4.0) 
        y_4025 = int(y / 4.0) 

        # Index in 40 x 25 array
        idx = y_4025 * 40 + x_4025

        if code == "00":
            color = bgcolor
        elif code == "01":
            #color = bgcolor
            color = ord(mc_v_data[idx]) & 0x0f
            #color = int(bin(ord(mc_v_data[idx]))[2:].zfill(8)[0:4],2)
        elif code == "10":
            #color = bgcolor
            color = ord(mc_v_data[idx]) >> 8
            #color = int(bin(ord(mc_v_data[idx]))[2:].zfill(8)[4:8],2)
        elif code == "11":
            #color = bgcolor
            color = ord(mc_c_data[idx]) & 0xf # o >> 8
            #color = int(bin(ord(mc_c_data[idx]))[2:].zfill(8)[4:8],2)

        color_t = pepto[color]
        color_s = "rgb(" + str(color_t[0]) +  "," + str(color_t[1]) + "," + str(color_t[2]) +  ")"
        #print color_s

        drw.fill_color = Color(color_s)
        drw.stroke_line_cap = 'square'
        drw.point(x,y)

drw(img)
img.save(filename='test.jpg')

