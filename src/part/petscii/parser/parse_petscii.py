#!/usr/bin/env python
import sys
import struct

if len(sys.argv) != 2:
    print("Usage: %s FILE.UCA")
    sys.exit(1)

fh = open(sys.argv[1], "rb")
bin = fh.read()
fh.close()

# Get cols and rows from header
cols = struct.unpack("i", bin[25:29])[0]
rows = struct.unpack("i", bin[29:33])[0]
print("Size: %dx%d" % (cols, rows))

fh = open("imagedata.c64", "w")
fh.write(str(cols) + "," + str(rows))
fh.close()

data = bin[69:] # skip ... header?

x, y = 0, 0

last = None
curr_color = 0
skip_bytes = 14
frame_n = 0

#s_data = "\x00\x20"
#c_data = "\x00\x80"

s_data = ""
c_data = ""

for i, b in enumerate(data):
    if skip_bytes:
        skip_bytes -= 1
        continue

    byt = ord(b)
    is_char = False
    if byt < 0x10:
        if last is not None and last[0] < 0x10 and last[1] == False: 
            # is char
            is_char = True
        else:
            # is color
            curr_color = byt
    else:
        is_char = True

    if is_char:
        print hex(byt)[2:].zfill(2),
        if byt == 0x64:
            byt = 0x20

        s_data += chr(byt)
        c_data += chr(curr_color)
        
        x += 1

        if x == cols:
            y += 1
            x = 0
            print ""

        if y == rows:
            print "-" * 80
            last = None
            curr_color = 0
            x, y = 0, 0
            skip_bytes = 14 # skip ... frame header?

            fh_s = open("screen-" + str(frame_n) + ".c64", "wb")
            fh_c = open("color-" + str(frame_n) + ".c64", "wb")

            #fh_s.write(packbits.encode(s_data))
            #fh_c.write(packbits.encode(c_data))
            fh_s.write(s_data)
            fh_c.write(c_data)

            fh_s.close()
            fh_c.close()

            frame_n += 1
            continue

    last = (byt, is_char)

print i + 83
